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
    vec: *Vector,
    matrix: *Matrix,
    array: *Array,
    ref: *MemoryView,
    ptr: *MemoryView,
    atomic: *Atomic,
    fn_decl: *FnDecl,
    struct_decl: *Struct,

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
            .abstract_int => try writer.writeAll("{integer}"),
            .abstract_float => try writer.writeAll("{float}"),
            .vec => |x| try writer.print("vec<{}>", .{x.item}),
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
            .struct_decl => |x| try writer.writeAll(x.name),
            .atomic => |x| try writer.print("atomic<{}>", .{x.inner}),
            .ref => |x| try writer.print("ref<{}>", .{x.inner}),
            else => @panic("."),
        }
    }

    pub fn isConstructible(self: Type) bool {
        return switch (self) {
            .bool, .abstract_int, .abstract_float, .u32, .i32, .f32, .f16 => true,
            .vec => |_| true,
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

    pub fn normalize(src: Type) Type {
        return if (src == .abstract_int) .i32 else if (src == .abstract_float) .f32 else if (src == .ref) src.ref.inner else src;
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
            .bool => dest == .bool,
            else => false,
        };
    }

    pub fn alignOf(t: Type) u32 {
        return switch (t) {
            .err => 0,
            .i32, .u32, .f32 => 4,
            .f16 => 2,
            .atomic => 4,
            else => @panic("."),
        };
    }
};

pub const TypeGenerator = struct {
    args: []Type,
};

pub const Vector = struct {
    item: Type,
    size: u32 = 0,
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

pub const Binding = struct {
    value: Type,
    flags: packed struct {
        is_const: bool = false,
        is_override: bool = false,
        is_function: bool = false,
    } = .{},
};

pub const Atomic = struct {
    inner: Type,
};

pub const Struct = struct {
    name: []const u8,
    members: std.StringArrayHashMapUnmanaged(Type),
};

pub const Env = struct {
    bindings: std.StringHashMapUnmanaged(Binding) = .{},
    parent: ?*Env = null,

    pub fn getBinding(env: *const Env, name: []const u8) ?Binding {
        return env.bindings.get(name) orelse
            if (env.parent) |parent| parent.getBinding(name) else null;
    }
};

allocator: std.mem.Allocator,
source: []const u8,
reporter: *Reporter,
extensions: Extensions = .{},
types: std.StringHashMapUnmanaged(Type) = .{},

pub const OpOverload = struct {
    kind: enum {
        neg,
        add,
        sub,
        mul,
        div,
        mod,

        i32,
        u32,
        bool,
        f32,
    },
    operands: [3]Type,
};

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

pub fn putBinding(self: *Self, env: *Env, span: ast.Span, binding: Binding) !void {
    var result = try env.bindings.getOrPut(self.allocator, self.readSpan(span));

    if (result.found_existing) {
        self.reporter.add(Diagnostic{
            .span = span,
            .kind = .{ .already_declared = self.readSpan(span) },
        });
    } else {
        result.value_ptr.* = binding;
    }
}

pub fn inferExpr(self: *Self, env: *Env, expr: Node) !Type {
    return switch (expr) {
        .err => .err,
        .identifier => |span| {
            var typ = env.getBinding(self.readSpan(span));
            return if (typ != null and !typ.?.flags.is_function) {
                return typ.?.value;
            } else {
                self.reporter.add(Diagnostic{
                    .span = span,
                    .kind = .{ .unknown_name = self.readSpan(span) },
                });
                return .err;
            };
        },
        .number_literal => |data| switch (data.kind) {
            .u32 => .u32,
            .i32 => .i32,
            .f32 => .f32,
            .f16 => .f16,
            .abstract_int => .abstract_int,
            .abstract_float => .abstract_float,
        },
        .boolean_literal => |_| .bool,
        .add, .sub, .mul, .div, .mod => |data| {
            var lhs = try self.inferExpr(env, data.lhs);
            var rhs = try self.inferExpr(env, data.rhs);

            if (!lhs.isNumber() and lhs != .err) {
                self.reporter.add(Diagnostic{
                    .span = data.lhs.span(),
                    .kind = .{ .expected_arithmetic_lhs = .{
                        .got = lhs,
                    } },
                });
            }

            if (!Type.isConversionPossible(rhs, lhs) and rhs != .err) {
                self.reporter.add(Diagnostic{
                    .span = data.rhs.span(),
                    .kind = .{ .not_assignable = .{
                        .expected = lhs,
                        .got = rhs,
                    } },
                });
            }

            return lhs;
        },
        .call => |data| {
            var callee = switch (data.callee) {
                .identifier => |span| blk: {
                    const name = self.readSpan(span);
                    const binding = env.getBinding(name) orelse {
                        break :blk try self.resolveType(env, data.callee);
                    };
                    break :blk binding.value;
                },
                .template => try self.resolveType(env, data.callee),
                else => try self.inferExpr(env, data.callee),
            };

            switch (callee) {
                inline .bool, .i32, .u32, .f32 => |_, kind| {
                    switch (data.args.len) {
                        0 => {},
                        1 => {
                            var arg_t = try self.inferExpr(env, data.args[0]);
                            if (!Type.isConversionPossible(arg_t, kind)) {
                                self.reporter.add(Diagnostic{
                                    .span = data.args[0].span(),
                                    .kind = .{ .not_assignable = .{
                                        .expected = kind,
                                        .got = arg_t,
                                    } },
                                });
                                return .err;
                            }
                        },
                        else => {
                            self.reporter.add(Diagnostic{ .span = expr.span(), .kind = .{ .expected_n_args = .{
                                .expected = 0,
                                .expected_max = 1,
                                .got = @truncate(data.args.len),
                            } } });
                            return .err;
                        },
                    }
                    return kind;
                },
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
                    for (data.args) |arg_t| {
                        _ = try self.inferExpr(env, arg_t);
                    }

                    // We don't want to double-error.
                    if (callee != .err) {
                        self.reporter.add(Diagnostic{
                            .span = data.callee.span(),
                            .kind = .{ .not_callable_type = callee },
                        });
                    }

                    return .err;
                },
            }
        },
        .cmp_and => |data| {
            var lhs_t = try self.inferExpr(env, data.lhs);
            var rhs_t = try self.inferExpr(env, data.rhs);

            if (lhs_t != .bool) {
                self.reporter.add(Diagnostic{
                    .span = data.lhs.span(),
                    .kind = .{ .not_assignable = .{
                        .expected = .bool,
                        .got = lhs_t,
                    } },
                });
            }

            if (rhs_t != .bool) {
                self.reporter.add(Diagnostic{
                    .span = data.rhs.span(),
                    .kind = .{ .not_assignable = .{
                        .expected = .bool,
                        .got = rhs_t,
                    } },
                });
            }

            return .bool;
        },
        .equal => |data| {
            var lhs_t = try self.inferExpr(env, data.lhs);
            var rhs_t = try self.inferExpr(env, data.rhs);

            if (!Type.isConversionPossible(rhs_t, lhs_t)) {
                self.reporter.add(Diagnostic{
                    .span = data.rhs.span(),
                    .kind = .{ .not_assignable = .{
                        .expected = lhs_t,
                        .got = rhs_t,
                    } },
                });
            }

            return .bool;
        },
        .not_equal => |data| {
            var lhs_t = try self.inferExpr(env, data.lhs);
            var rhs_t = try self.inferExpr(env, data.rhs);

            if (!Type.isConversionPossible(rhs_t, lhs_t)) {
                self.reporter.add(Diagnostic{
                    .span = data.rhs.span(),
                    .kind = .{ .not_assignable = .{
                        .expected = lhs_t,
                        .got = rhs_t,
                    } },
                });
            }

            return .bool;
        },
        .member => |data| {
            var lhs_t = (try self.inferExpr(env, data.lhs)).normalize();

            if (data.rhs == .err) return .err;

            var member = self.readSpan(data.rhs.identifier);

            if (lhs_t == .struct_decl) {
                if (lhs_t.struct_decl.members.get(member)) |typ| {
                    return typ;
                }
            }

            self.reporter.add(Diagnostic{
                .span = data.rhs.span(),
                .kind = .{ .no_member = .{
                    .typ = lhs_t,
                    .member = member,
                } },
            });

            return .err;
        },
        else => std.debug.panic("Unimplemented: {}", .{expr}),
    };
}

const BuiltinTemplate = union(enum) {
    atomic,
    array,
    matrix: packed struct {
        width: u8,
        height: u8,
    },
    ptr,
    texture_1d,
    texture_2d,
    texture_2d_array,
    texture_3d,
    texture_cube,
    texture_cube_array,
    texture_multisampled_2d,
    texture_storage_1d,
    texture_storage_2d,
    texture_storage_2d_array,
    texture_storage_3d,
    vec2,
    vec3,
    vec4,

    pub const Map = std.ComptimeStringMap(BuiltinTemplate, .{
        .{ "atomic", .atomic },
        .{ "array", .array },
        .{ "mat2x2", .{ .matrix = .{ .width = 2, .height = 2 } } },
        .{ "mat2x3", .{ .matrix = .{ .width = 2, .height = 3 } } },
        .{ "mat2x4", .{ .matrix = .{ .width = 2, .height = 4 } } },
        .{ "mat3x2", .{ .matrix = .{ .width = 3, .height = 2 } } },
        .{ "mat3x3", .{ .matrix = .{ .width = 3, .height = 3 } } },
        .{ "mat3x4", .{ .matrix = .{ .width = 3, .height = 4 } } },
        .{ "mat4x2", .{ .matrix = .{ .width = 4, .height = 2 } } },
        .{ "mat4x3", .{ .matrix = .{ .width = 4, .height = 3 } } },
        .{ "mat4x4", .{ .matrix = .{ .width = 4, .height = 4 } } },
        .{ "ptr", .ptr },
        .{ "texture_1d", .texture_1d },
        .{ "texture_2d", .texture_2d },
        .{ "texture_2d_array", .texture_2d_array },
        .{ "texture_3d", .texture_3d },
        .{ "texture_cube", .texture_cube },
        .{ "texture_cube_array", .texture_cube_array },
        .{ "texture_multisampled_2d", .texture_multisampled_2d },
        .{ "texture_storage_1d", .texture_storage_1d },
        .{ "texture_storage_2d", .texture_storage_2d },
        .{ "texture_storage_2d_array", .texture_storage_2d_array },
        .{ "texture_storage_3d", .texture_storage_3d },
        .{ "vec2", .vec2 },
        .{ "vec3", .vec3 },
        .{ "vec4", .vec4 },
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
        .struct_decl => |data| {
            var members: std.StringArrayHashMapUnmanaged(Type) = .{};

            try members.ensureTotalCapacity(self.allocator, @truncate(data.members.len));
            for (data.members) |member| {
                var name = self.readSpan(member.labeled_type.name);
                var value = try self.resolveType(env, member.labeled_type.typ);
                members.putAssumeCapacity(name, value);
            }

            var ptr = try self.allocator.create(Struct);
            ptr.* = .{ .name = self.readSpan(data.name), .members = members };

            return Type{ .struct_decl = ptr };
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
                .array => {
                    if (data.args.len != 1 and data.args.len != 2) {
                        self.reporter.add(Diagnostic{
                            .span = data.name,
                            .kind = .{ .expected_n_template_args = .{
                                .expected = 1,
                                .expected_max = 2,
                                .got = @truncate(data.args.len),
                            } },
                        });
                    }
                    var ptr = try self.allocator.create(Array);
                    ptr.* = .{
                        .item = try self.resolveType(env, data.args[0]),
                        .length = null,
                    };
                    return Type{ .array = ptr };
                },
                .matrix => |mat| {
                    if (data.args.len != 1) {
                        self.reporter.add(Diagnostic{
                            .span = data.name,
                            .kind = .{ .expected_n_template_args = .{
                                .expected = 1,
                                .got = @truncate(data.args.len),
                            } },
                        });
                    }

                    var ptr = try self.allocator.create(Matrix);
                    ptr.* = .{
                        .item = try self.resolveType(env, data.args[0]),
                        .width = mat.width,
                        .height = mat.height,
                    };
                    return Type{ .matrix = ptr };
                },
                .ptr => {
                    if (data.args.len != 1) {
                        self.reporter.add(Diagnostic{
                            .span = data.name,
                            .kind = .{ .expected_n_template_args = .{
                                .expected = 1,
                                .got = @truncate(data.args.len),
                            } },
                        });
                    }

                    var ptr = try self.allocator.create(MemoryView);
                    ptr.* = .{
                        .addr_space = .function,
                        .inner = try self.resolveType(env, data.args[0]),
                        .access_mode = .read_write,
                    };

                    return Type{ .ptr = ptr };
                },
                else => std.debug.panic("{}", .{kind}),
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
            seed.update(&.{@intFromEnum(s.kind)});
            seed.update(s.name);
            return seed.final();
        }

        pub fn eql(ctx: @This(), a: DependencyKey, b: DependencyKey) bool {
            _ = ctx;
            return a.kind == b.kind and std.mem.eql(u8, a.name, b.name);
        }
    };

    var graph = std.HashMap(DependencyKey, DependencyNode, DependencyContext, 80).init(allocator);

    // Create the vertices for the dependency nodes.
    for (scope) |node| {
        switch (node) {
            .struct_decl => |data| {
                var stat = try graph.getOrPut(.{
                    .name = self.readSpan(data.name),
                    .kind = .alias,
                });

                if (stat.found_existing) {
                    self.reporter.add(Diagnostic{
                        .span = data.name,
                        .kind = .{ .already_declared = self.readSpan(data.name) },
                    });
                } else {
                    stat.value_ptr.* = DependencyNode{
                        .name = data.name,
                        .value = node,
                        .children = .{ .refs = try self.getDependencies(node) },
                    };
                }
            },
            .type_alias => |data| {
                var stat = try graph.getOrPut(.{
                    .name = self.readSpan(data.name),
                    .kind = .alias,
                });

                if (stat.found_existing) {
                    self.reporter.add(Diagnostic{
                        .span = data.name,
                        .kind = .{ .already_declared = self.readSpan(data.name) },
                    });
                } else {
                    stat.value_ptr.* = DependencyNode{
                        .name = data.name,
                        .value = data.value,
                        .children = .{ .refs = try self.getDependencies(data.value) },
                    };
                }
            },
            .fn_decl => |data| {
                var stat = try graph.getOrPut(.{
                    .name = self.readSpan(data.name),
                    .kind = .function,
                });

                if (stat.found_existing) {
                    self.reporter.add(Diagnostic{
                        .span = data.name,
                        .kind = .{ .already_declared = self.readSpan(data.name) },
                    });
                } else {
                    var children = std.ArrayList(DependencyNode.Ref).init(allocator);
                    for (data.params) |param_t| {
                        try children.appendSlice(try self.getDependencies(param_t));
                    }
                    if (data.ret) |ret_t| {
                        try children.appendSlice(try self.getDependencies(ret_t));
                    }

                    stat.value_ptr.* = DependencyNode{
                        .name = data.name,
                        .value = node,
                        .children = .{ .refs = try children.toOwnedSlice() },
                    };
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

    // Emit the declarations.
    for (stack.items) |node| {
        var resolved = try self.resolveType(env, node.value);

        if (node.value == .fn_decl) {
            try env.bindings.put(
                self.allocator,
                self.readSpan(node.value.fn_decl.name),
                Binding{ .value = resolved, .flags = .{ .is_function = true } },
            );
            continue;
        }

        try self.types.put(self.allocator, self.readSpan(node.name), resolved);
    }
}

fn getDependencies(self: *Self, node: Node) ![]DependencyNode.Ref {
    var deps: std.ArrayListUnmanaged(DependencyNode.Ref) = .{};
    try self.pushDependencies(&deps, node);
    return deps.toOwnedSlice(self.allocator);
}

fn pushDependencies(self: *Self, deps: *std.ArrayListUnmanaged(DependencyNode.Ref), node: Node) !void {
    switch (node) {
        .struct_decl => |data| {
            for (data.members) |member| {
                try self.pushDependencies(deps, member);
            }
        },
        .identifier => |span| {
            var name = self.readSpan(span);
            if (!self.types.contains(name)) {
                try deps.append(self.allocator, .{
                    .name = span,
                    .kind = .alias,
                });
            }
        },
        .labeled_type => |data| {
            try self.pushDependencies(deps, data.typ);
        },
        .template => |data| {
            for (data.args) |arg| {
                try self.pushDependencies(deps, arg);
            }
        },
        else => {},
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
        .err => {},
        .discard => {},
        .const_assert => |data| {
            _ = try self.inferExpr(env, data.value);
        },
        .override_decl => |data| {
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
                    try self.putBinding(env, data.name, Binding{ .value = t, .flags = .{ .is_override = true } });
                } else {
                    try self.putBinding(env, data.name, Binding{ .value = value_t, .flags = .{ .is_override = true } });
                }
            } else if (data.typ) |typ| {
                var t = try self.resolveType(env, typ);
                try self.putBinding(env, data.name, Binding{ .value = t, .flags = .{ .is_override = true } });
            }
        },
        .let_decl => |data| {
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
                _ = try self.putBinding(env, data.name, Binding{ .value = t });
            } else {
                _ = try self.putBinding(env, data.name, Binding{ .value = value_t.normalize() });
            }
        },
        .var_decl => |data| {
            var value_t = if (data.value) |expr|
                try self.inferExpr(env, expr)
                // TODO: verify constructible
            else if (data.typ) |typ| try self.resolveType(env, typ) else @panic(".");

            var ptr = try self.allocator.create(MemoryView);
            ptr.* = MemoryView{
                .addr_space = data.addr_space orelse .function,
                .inner = value_t.normalize(),
                .access_mode = data.access_mode,
            };

            _ = try self.putBinding(env, data.name, Binding{ .value = Type{ .ref = ptr } });
        },
        .type_alias => {},
        .struct_decl => {},
        .fn_decl => |data| {
            var scope = Env{ .parent = env };

            try scope.bindings.ensureTotalCapacity(self.allocator, @truncate(data.params.len));
            for (data.params) |param| {
                var p: *ast.LabeledType = if (param == .attributed)
                    param.attributed.inner.labeled_type
                else
                    param.labeled_type;

                scope.bindings.putAssumeCapacity(
                    self.readSpan(p.name),
                    .{ .value = try self.resolveType(env, p.typ) },
                );
            }

            var ret_t = if (data.ret) |ret| try self.resolveType(env, if (ret == .attributed) ret.attributed.inner else ret) else null;

            for (data.scope) |n| {
                switch (n) {
                    .ret => |ret_data| {
                        if (ret_data.value) |ret| {
                            if (ret_t) |expected_t| {
                                var got_t = try self.inferExpr(env, ret);
                                if (!Type.isConversionPossible(got_t, expected_t)) {
                                    self.reporter.add(Diagnostic{
                                        .span = ret.span(),
                                        .kind = .{ .not_assignable = .{
                                            .expected = expected_t,
                                            .got = got_t,
                                        } },
                                    });
                                }
                            }
                        } else if (ret_t != null) {
                            self.reporter.add(Diagnostic{
                                .span = n.span(),
                                .kind = .{ .not_assignable = .{
                                    .expected = ret_t.?,
                                    .got = .err,
                                } },
                            });
                        }
                    },
                    else => try self.check(&scope, n),
                }
            }
        },
        .call => {
            _ = try self.inferExpr(env, node);
        },
        .if_stmt => {
            var next: ?Node = node;
            while (next) |data| {
                var sub_env = Env{ .parent = env };
                switch (data) {
                    .if_stmt => |d| {
                        var condition = try self.inferExpr(env, d.expression);

                        if (condition != .bool and condition != .err) {
                            self.reporter.add(Diagnostic{
                                .span = d.expression.span(),
                                .kind = .{ .not_assignable = .{
                                    .expected = .bool,
                                    .got = condition,
                                } },
                            });
                        }

                        for (d.scope) |n| {
                            try self.check(&sub_env, n);
                        }

                        next = if (d.next) |n| n.* else null;
                    },
                    .else_stmt => |d| {
                        for (d.scope) |n| {
                            try self.check(&sub_env, n);
                        }

                        next = null;
                    },
                    else => unreachable,
                }
            }
        },
        .attributed => |data| {
            try self.check(env, data.inner);
        },
        .while_stmt => |data| {
            var expression = try self.inferExpr(env, data.expression);

            if (!Type.isConversionPossible(expression, .bool)) {
                self.reporter.add(Diagnostic{
                    .span = data.expression.span(),
                    .kind = .{ .not_assignable = .{
                        .expected = .bool,
                        .got = expression,
                    } },
                });
            }

            var sub_env = Env{ .parent = env };
            for (data.scope) |n| {
                try self.check(&sub_env, n);
            }
        },
        .loop => |data| {
            var sub_env = Env{ .parent = env };
            for (data.scope) |n| {
                try self.check(&sub_env, n);
            }
        },
        .assign => |data| {
            var lhs_t = try self.inferExpr(env, data.lhs);

            if (lhs_t != .ref) {
                self.reporter.add(Diagnostic{
                    .span = data.lhs.span(),
                    .kind = .{ .assignment_not_ref = lhs_t },
                });
                _ = try self.inferExpr(env, data.rhs);
                return;
            }

            var rhs_t = try self.inferExpr(env, data.rhs);

            if (!Type.isConversionPossible(rhs_t, lhs_t.ref.inner)) {
                self.reporter.add(Diagnostic{
                    .span = data.rhs.span(),
                    .kind = .{ .not_assignable = .{
                        .expected = lhs_t.ref.inner,
                        .got = rhs_t,
                    } },
                });
            }
        },
        else => std.debug.panic("Unimplemented: {}", .{node}),
    }
}
