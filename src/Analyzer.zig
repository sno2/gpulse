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

pub const TypeBinding = union(enum) {
    alias: Type,
    template: *TypeGenerator,
};

pub const Binding = union(enum) {
    binding: Type,
};

pub const Env = struct {
    types: std.StringHashMapUnmanaged(TypeBinding) = .{},
    bindings: std.StringHashMapUnmanaged(Binding) = .{},
    parent: ?*Env = null,

    pub fn getBinding(env: *const Env, name: []const u8) ?Binding {
        return env.bindings.get(name) orelse
            if (env.parent) |parent| parent.getBinding(name) else null;
    }

    pub fn getType(env: *const Env, name: []const u8) ?TypeBinding {
        return env.types.get(name) orelse
            if (env.parent) |parent| parent.getType(name) else null;
    }
};

allocator: std.mem.Allocator,
source: []const u8,
reporter: *Reporter,
extensions: Extensions = .{},
types: std.StringHashMapUnmanaged(TypeBinding) = .{},

pub fn loadGlobalTypes(self: *Self) !void {
    var map = &.{
        .{ "bool", .{ .alias = .bool } },
        .{ "i32", .{ .alias = .i32 } },
        .{ "u32", .{ .alias = .u32 } },
        .{ "f32", .{ .alias = .f32 } },
    };

    try self.types.ensureTotalCapacity(self.allocator, map.len);
    inline for (map) |v| {
        self.types.putAssumeCapacityNoClobber(v.@"0", v.@"1");
    }

    if (self.extensions.enable_f16) {
        try self.types.putNoClobber(self.allocator, "f16", .{ .alias = .f16 });
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
            } else .err;
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
        else => std.debug.panic("Unimplemented: {}", .{expr}),
    };
}

pub inline fn resolveType(self: *Self, env: *Env, typ: Node) !Type {
    return self.resolveTypeOptions(env, typ, true);
}

pub const UnresolvedError = error{Unresolved};

fn resolveTypeOptions(self: *Self, env: *Env, typ: Node, comptime fail_unresolved: bool) UnresolvedError!Type {
    _ = env;
    return switch (typ) {
        .identifier => |span| {
            var name = self.readSpan(span);
            var decl = self.types.get(name);

            if (decl == null or decl.? != .alias) {
                if (fail_unresolved) {
                    self.reporter.add(Diagnostic{
                        .span = span,
                        .kind = .{ .unknown_type = name },
                    });
                    return .err;
                } else {
                    return error.Unresolved;
                }
            }

            return decl.?.alias;
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
        names: []ast.Span,
        // Second stage
        nodes: []*DependencyNode,
    },
};

/// Loads all global aliases.
pub fn loadTypes(self: *Self, env: *Env, scope: []const Node) !void {
    var fallback = std.heap.stackFallback(1024, self.allocator);
    var allocator = fallback.get();

    var graph = std.AutoHashMap(ast.Span, DependencyNode).init(allocator);

    // Create the vertices for the dependency nodes.
    for (scope) |node| {
        switch (node) {
            .type_alias => |data| {
                switch (data.value) {
                    .identifier => |span| {
                        var name = self.readSpan(span);
                        if (self.types.contains(name)) {
                            try graph.put(span, DependencyNode{
                                .name = data.name,
                                .value = data.value,
                                .children = .{ .names = &.{} },
                            });
                        } else {
                            try graph.put(span, DependencyNode{
                                .name = data.name,
                                .value = data.value,
                                .children = .{ .names = try allocator.dupe(ast.Span, &.{span}) },
                            });
                        }
                    },
                    else => @panic("Todo"),
                }
            },
            else => {},
        }
    }

    // Exit early if no sorting work is required.
    if (graph.count() == 0) {
        return;
    }

    // Create the children for each of the dependency nodes.
    var iter1 = graph.valueIterator();
    while (iter1.next()) |value| {
        var names = value.children.names;
        var nodes = try allocator.alloc(*DependencyNode, names.len);

        for (names, 0..) |name, i| {
            // TODO: handle unknown type name
            nodes[i] = graph.getPtr(name) orelse @panic("");
        }

        value.children = .{ .nodes = nodes };
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
    while (stack.popOrNull()) |node| {
        self.types.putAssumeCapacity(self.readSpan(node.name), .{
            .alias = try self.resolveType(env, node.value),
        });
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
                            .span = data.name,
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
        else => std.debug.panic("Unimplemented: {}", .{node}),
    }
}
