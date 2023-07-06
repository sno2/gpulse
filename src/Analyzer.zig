const std = @import("std");
const ast = @import("ast.zig");
const Node = ast.Node;
const Reporter = @import("Reporter.zig");
const Diagnostic = Reporter.Diagnostic;
const Extensions = @import("Extensions.zig");
const Self = @This();

pub const Type = union(enum) {
    err,
    bool,
    u32,
    i32,
    f32,
    f16,
    abstract_int,
    abstract_float,
    vector: *Vector,
    matrix: *Matrix,
    array: *Array,
    ref: *MemoryView,
    ptr: *MemoryView,
    fn_decl: *FnDecl,
    atomic: *Atomic,

    pub const FnDecl = struct {
        params: []Type,
        ret: ?Type,
    };

    pub fn format(self: Type, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (self) {
            .err => try writer.writeAll("[error]"),
            .bool => try writer.writeAll("bool"),
            .u32 => try writer.writeAll("u32"),
            .i32 => try writer.writeAll("i32"),
            .f32 => try writer.writeAll("f32"),
            .f16 => try writer.writeAll("f16"),
            .abstract_int => try writer.writeAll("AbstractInt"),
            .abstract_float => try writer.writeAll("AbstractFloat"),
            .vector => |x| try writer.print("vec<{}>", .{x.item}),
            .matrix => |x| try writer.print("mat{}x{}<{}>", .{ x.width, x.height, x.item }),
            .array => |x| {
                try writer.print("array<{}", .{x.item});
                if (x.length) |len| {
                    try writer.print(", {}", .{len});
                }
                try writer.writeAll(">");
            },
            .fn_decl => |x| {
                try writer.writeAll("fn(");

                for (x.params[0..x.params.len -| 1]) |param| {
                    try writer.print("{}, ", .{param});
                }

                if (x.params.len != 0) {
                    try writer.print("{})", .{x.params[x.params.len - 1]});
                } else {
                    try writer.writeAll(")");
                }

                if (x.ret) |ret| {
                    try writer.print(" -> {}", .{ret});
                }
            },
            .atomic => |x| try writer.print("atomic<{}>", .{x.inner}),
            else => @panic("."),
        }
    }

    pub fn isConstructible(self: Type) bool {
        return switch (self) {
            .bool, .abstract_int, .abstract_float, .u32, .i32, .f32, .f16 => true,
            .vector => |_| true,
            .matrix => |_| true,
            .array => |arr| if (arr.length == null) false else arr.item.isConstructible(),
            // TODO: structures
            else => false,
        };
    }

    pub fn isNumber(self: Type) bool {
        return switch (self) {
            .abstract_int, .abstract_float, .u32, .i32, .f32, .f16 => true,
            else => false,
        };
    }

    /// Answers if ConversionRank(Src,Dest) != Infinity
    pub fn isConversionPossible(src: Type, dest: Type) bool {
        if (dest == .err) return true;
        return switch (src) {
            .err => true,
            .ref => |data| isConversionPossible(data.inner, dest),
            .abstract_float => dest == .abstract_float or dest == .f32 or dest == .f16,
            .abstract_int => dest == .abstract_int or dest == .i32 or dest == .u32 or dest == .abstract_float or dest == .f32 or dest == .f16,
            .i32 => dest == .i32,
            .u32 => dest == .u32,
            .f32 => dest == .f32,
            .f16 => dest == .f16,
            else => false,
        };
    }
};

pub const TypeGenerator = struct {
    args: []Type,
};

pub const Vector = struct {
    item: Type,
};

pub const Matrix = struct {
    item: Type,
    width: u32,
    height: u32,
};

pub const Array = struct {
    item: Type,
    length: ?u32,
};

// https://www.w3.org/TR/WGSL/#ref-ptr-types
pub const MemoryView = struct {
    addr_space: ast.AddrSpace,
    inner: Type,
    access_mode: ast.AccessMode,
};

pub const Binding = union(enum) {
    binding: Type,
};

pub const Atomic = struct {
    inner: Type,
};

pub const Env = struct {
    types: std.StringHashMapUnmanaged(Type) = .{},
    bindings: std.StringHashMapUnmanaged(Binding) = .{},
    parent: ?*Env = null,

    pub fn getBinding(env: *const Env, name: []const u8) ?Binding {
        return env.bindings.get(name) orelse
            if (env.parent) |parent| parent.getBinding(name) else null;
    }

    pub fn getType(env: *const Env, name: []const u8) ?Type {
        return env.types.get(name) orelse
            if (env.parent) |parent| parent.getType(name) else null;
    }
};

allocator: std.mem.Allocator,
source: []const u8,
reporter: *Reporter,
extensions: Extensions = .{},
types: std.StringHashMapUnmanaged(Type) = .{},

pub fn loadGlobalTypes(self: *Self) !void {
    var map = &.{
        .{ "bool", .bool },
        .{ "i32", .i32 },
        .{ "u32", .u32 },
        .{ "f32", .f32 },
    };

    try self.types.ensureTotalCapacity(self.allocator, map.len);
    inline for (map) |v| {
        self.types.putAssumeCapacityNoClobber(v.@"0", v.@"1");
    }

    if (self.extensions.enable_f16) {
        try self.types.putNoClobber(self.allocator, "f16", .f16);
    }
}

inline fn readSpan(self: *const Self, span: ast.Span) []const u8 {
    return self.source[span.start..span.end];
}

pub fn putBinding(self: *Self, env: *Env, name: []const u8, binding: Binding) !bool {
    var result = try env.bindings.getOrPut(self.allocator, name);

    if (result.found_existing) {
        result.value_ptr.* = binding;
        return true;
    } else {
        return false;
    }
}

pub fn inferExpr(self: *Self, env: *Env, expr: Node) !Type {
    return switch (expr) {
        .err => Type{ .err = {} },
        .identifier => |span| {
            var typ = env.getBinding(self.readSpan(span));

            return if (typ) |t| switch (t) {
                .binding => |ty| ty,
            } else {
                self.reporter.add(Diagnostic{
                    .span = span,
                    .kind = .{ .unknown_name = self.readSpan(span) },
                });
                return .err;
            };
        },
        .number_literal => |data| switch (data.kind) {
            .u32 => .{ .u32 = {} },
            .i32 => .{ .i32 = {} },
            .f32 => .{ .f32 = {} },
            .f16 => .{ .f16 = {} },
            .abstract_int => .{ .abstract_int = {} },
            .abstract_float => .{ .abstract_float = {} },
        },
        .boolean_literal => |_| .{ .bool = {} },
        .add, .sub, .mul, .div, .mod => |data| {
            var lhs = try self.inferExpr(env, data.lhs);
            var rhs = try self.inferExpr(env, data.rhs);

            if (!lhs.isNumber()) {}
            if (!rhs.isNumber()) {}

            return .{ .u32 = {} };
        },
        .call => |data| {
            var callee = try self.resolveType(env, data.callee);

            switch (callee) {
                .fn_decl => |fn_decl| {
                    if (data.args.len > fn_decl.params.len) {
                        self.reporter.add(Diagnostic{ .span = ast.Span.init(
                            data.args[fn_decl.params.len].span().start,
                            data.args[data.args.len -| 1].span().end,
                        ), .kind = .{ .expected_n_args = .{
                            .expected = @truncate(fn_decl.params.len),
                            .got = @truncate(data.args.len),
                        } } });
                    } else if (data.args.len < fn_decl.params.len) {
                        self.reporter.add(Diagnostic{ .span = expr.span(), .kind = .{ .expected_n_args = .{
                            .expected = @truncate(fn_decl.params.len),
                            .got = @truncate(data.args.len),
                        } } });
                    }

                    var end = @min(data.args.len, fn_decl.params.len);
                    for (data.args[0..end], fn_decl.params[0..end]) |arg, param_t| {
                        var arg_t = try self.inferExpr(env, arg);
                        if (!Type.isConversionPossible(arg_t, param_t)) {
                            self.reporter.add(Diagnostic{
                                .span = arg.span(),
                                .kind = .{ .not_assignable = .{
                                    .expected = param_t,
                                    .got = arg_t,
                                } },
                            });
                        }
                    }

                    for (data.args[end..]) |arg| {
                        _ = try self.inferExpr(env, arg);
                    }

                    return fn_decl.ret orelse .err;
                },
                else => {
                    self.reporter.add(Diagnostic{
                        .span = data.callee.span(),
                        .kind = .{ .not_callable_type = callee },
                    });

                    for (data.args) |arg_t| {
                        _ = try self.inferExpr(env, arg_t);
                    }

                    return .err;
                },
            }
        },
        else => std.debug.panic("Unimplemented: {}", .{expr}),
    };
}

const BuiltinTemplate = enum {
    atomic,

    pub const Map = std.ComptimeStringMap(BuiltinTemplate, .{
        .{ "atomic", .atomic },
    });
};

fn resolveType(self: *Self, env: *Env, typ: Node) !Type {
    return switch (typ) {
        .identifier => |span| {
            var name = self.readSpan(span);
            var t = self.types.get(name) orelse {
                self.reporter.add(Diagnostic{
                    .span = span,
                    .kind = .{ .unknown_type = name },
                });
                return .err;
            };

            return t;
        },
        .fn_decl => |data| {
            var ptr = try self.allocator.create(Type.FnDecl);
            var params = try self.allocator.alloc(Type, data.params.len);
            ptr.ret = if (data.ret) |ret| try self.resolveType(env, ret) else null;
            ptr.params = params;
            for (data.params, 0..) |node, i| {
                params[i] = try self.resolveType(env, node.labeled_type.typ);
            }
            return Type{ .fn_decl = ptr };
        },
        .template => |data| {
            const kind = BuiltinTemplate.Map.get(self.readSpan(data.name)) orelse {
                self.reporter.add(Diagnostic{
                    .span = data.name,
                    .kind = .{ .unknown_type = self.readSpan(data.name) },
                });
                return .err;
            };

            switch (kind) {
                .atomic => {
                    if (data.args.len != 1) {
                        self.reporter.add(Diagnostic{
                            .span = data.name,
                            .kind = .{ .expected_n_template_args = .{
                                .expected = 1,
                                .got = @truncate(data.args.len),
                            } },
                        });
                    }
                    var ptr = try self.allocator.create(Atomic);
                    ptr.* = .{ .inner = try self.resolveType(env, data.args[0]) };
                    return Type{ .atomic = ptr };
                },
            }
        },
        else => std.debug.panic("Unimplemented: {}", .{typ}),
    };
}

const DependencyNode = struct {
    name: ast.Span,
    value: Node,
    visited: bool = false,
    children: union(enum) {
        // First stage
        refs: []DependencyNode.Ref,
        // Second stage
        nodes: []*DependencyNode,
    },

    pub const Ref = struct {
        name: ast.Span,
        kind: Kind,
    };

    pub const Kind = enum {
        constant,
        alias,
        function,
    };
};

/// Loads all global aliases.
pub fn loadTypes(self: *Self, env: *Env, scope: []const Node) !void {
    var fallback = std.heap.stackFallback(1024, self.allocator);
    var allocator = fallback.get();

    const DependencyKey = struct {
        name: []const u8,
        kind: DependencyNode.Kind,
    };

    const DependencyContext = struct {
        pub fn hash(_: @This(), s: DependencyKey) u64 {
            var seed = std.hash.Wyhash.init(0);
            seed.update(s.name);
            seed.update(&.{@intFromEnum(s.kind)});
            return seed.final();
        }

        pub fn eql(ctx: @This(), a: DependencyKey, b: DependencyKey) bool {
            return ctx.hash(a) == ctx.hash(b);
        }
    };

    var graph = std.HashMap(DependencyKey, DependencyNode, DependencyContext, 80).init(allocator);

    // Create the vertices for the dependency nodes.
    for (scope) |node| {
        switch (node) {
            .type_alias => |data| {
                try graph.put(.{
                    .name = self.readSpan(data.name),
                    .kind = .alias,
                }, DependencyNode{
                    .name = data.name,
                    .value = data.value,
                    .children = .{ .refs = try self.getDependencies(allocator, data.value) },
                });
            },
            .fn_decl => |data| {
                var children = std.ArrayList(DependencyNode.Ref).init(allocator);
                for (data.params) |param_t| {
                    try children.appendSlice(try self.getDependencies(allocator, param_t));
                }
                if (data.ret) |ret_t| {
                    try children.appendSlice(try self.getDependencies(allocator, ret_t));
                }

                try graph.put(.{
                    .name = self.readSpan(data.name),
                    .kind = .alias,
                }, DependencyNode{
                    .name = data.name,
                    .value = node,
                    .children = .{ .refs = try children.toOwnedSlice() },
                });
            },
            else => {},
        }
    }

    // Exit early if no sorting work is required.
    if (graph.count() == 0) {
        return;
    }

    // Create the children for each of the dependency nodes.
    var iter1 = graph.iterator();
    while (iter1.next()) |entry| {
        var refs = entry.value_ptr.children.refs;
        var nodes = try std.ArrayList(*DependencyNode).initCapacity(self.allocator, refs.len);

        for (refs) |ref| {
            nodes.appendAssumeCapacity(
                graph.getPtr(.{
                    .name = self.readSpan(ref.name),
                    .kind = ref.kind,
                }) orelse continue, // We will report the issue later.
            );
        }

        entry.value_ptr.children = .{ .nodes = try nodes.toOwnedSlice() };
    }

    // Sort the dependencies using a topological sort.
    var stack = try std.ArrayList(DependencyNode).initCapacity(allocator, graph.count());

    var iter2 = graph.valueIterator();
    while (iter2.next()) |value| {
        if (!value.visited) {
            dfs(value, &stack);
        }
    }

    // Emit the type declarations.
    try self.types.ensureUnusedCapacity(self.allocator, @truncate(stack.items.len));
    for (stack.items) |node| {
        self.types.putAssumeCapacity(self.readSpan(node.name), try self.resolveType(env, node.value));
    }
}

fn getDependencies(self: *Self, allocator: std.mem.Allocator, node: Node) ![]DependencyNode.Ref {
    switch (node) {
        .identifier => |span| {
            var name = self.readSpan(span);
            if (self.types.contains(name)) {
                return &.{};
            } else {
                return try allocator.dupe(DependencyNode.Ref, &.{.{
                    .name = span,
                    .kind = .alias,
                }});
            }
        },
        .labeled_type => |data| {
            return self.getDependencies(allocator, data.typ);
        },
        .template => |data| {
            var deps = std.ArrayList(DependencyNode.Ref).init(allocator);
            for (data.args) |arg| {
                try deps.appendSlice(try self.getDependencies(allocator, arg));
            }
            return deps.toOwnedSlice();
        },
        else => std.debug.panic("unimplemented: {}", .{node}),
    }
}

// Depth-first search on the graph.
fn dfs(node: *DependencyNode, stack: *std.ArrayList(DependencyNode)) void {
    node.visited = true;

    var i: usize = 0;
    while (i < node.children.nodes.len) : (i += 1) {
        var child = node.children.nodes.ptr[i];
        if (!child.visited) {
            dfs(child, stack);
        }
    }

    stack.appendAssumeCapacity(node.*);
}

pub fn check(self: *Self, env: *Env, node: Node) !void {
    switch (node) {
        .discard => {},
        .const_assert => |data| {
            _ = try self.inferExpr(env, data.value);
        },
        .override_decl => |data| {
            var name = self.readSpan(data.name);

            if (data.value) |value| {
                var value_t = try self.inferExpr(env, value);

                if (data.typ) |typ| {
                    var t = try self.resolveType(env, typ);
                    if (!Type.isConversionPossible(value_t, t)) {
                        self.reporter.add(Diagnostic{
                            .span = value.span(),
                            .kind = .{ .not_assignable = .{
                                .expected = t,
                                .got = value_t,
                            } },
                        });
                    }
                    _ = try self.putBinding(env, name, Binding{ .binding = t });
                } else {
                    _ = try self.putBinding(env, name, Binding{ .binding = value_t });
                }
            } else if (data.typ) |typ| {
                var t = try self.resolveType(env, typ);
                _ = try self.putBinding(env, name, Binding{ .binding = t });
            }
        },
        .let_decl => |data| {
            var name = self.readSpan(data.name);

            var value = data.value;
            var value_t = try self.inferExpr(env, value);

            if (data.typ) |typ| {
                var t = try self.resolveType(env, typ);
                if (!Type.isConversionPossible(value_t, t)) {
                    self.reporter.add(Diagnostic{
                        .span = value.span(),
                        .kind = .{ .not_assignable = .{
                            .expected = t,
                            .got = value_t,
                        } },
                    });
                }
                _ = try self.putBinding(env, name, Binding{ .binding = t });
            } else {
                _ = try self.putBinding(env, name, Binding{ .binding = value_t });
            }
        },
        .var_decl => |data| {
            var name = self.readSpan(data.name);
            var value_typ = if (data.value) |expr|
                try self.inferExpr(env, expr)
            else
                @panic(".");
            _ = try self.putBinding(env, name, Binding{ .binding = value_typ });
        },
        .type_alias => {},
        .fn_decl => |data| {
            for (data.scope) |n| {
                try self.check(env, n);
            }
        },
        .call => |data| {
            var callee = try self.resolveType(env, data.callee);

            if (callee != .fn_decl) {
                self.reporter.add(Diagnostic{
                    .span = data.callee.span(),
                    .kind = .{ .not_callable_type = callee },
                });
                return;
            }
        },
        else => std.debug.panic("Unimplemented: {}", .{node}),
    }
}
