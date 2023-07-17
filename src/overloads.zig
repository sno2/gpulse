// TODO: Generate a ".blob" file and use `@embedFile` instead of creating on
//       every compile.

const std = @import("std");
const Analyzer = @import("Analyzer.zig");
const Type = Analyzer.Type;

pub fn get(overload: Overload) ?usize {
    const hash = Overload.Context.hash(.{}, overload);
    return std.sort.binarySearch(
        u64,
        hash,
        &sorted.hashes,
        {},
        struct {
            pub fn cmp(_: void, lhs: u64, rhs: u64) std.math.Order {
                return std.math.order(lhs, rhs);
            }
        }.cmp,
    );
}

/// The ordered collection of hashes for the overloads.
pub const sorted: struct {
    hashes: [overloads.len]u64,
    results: [overloads.len]Type,
    overloads: [overloads.len]Overload,
} = blk: {
    @setEvalBranchQuota(10_000);

    var hashes: [overloads.len]u64 = undefined;

    // We will blissfully ignore the precense of hash collisions on the
    // overloads.
    for (overloads, 0..) |overload, i| {
        hashes[i] = Overload.Context.hash(.{}, overload.lower());
    }

    std.mem.sort(u64, &hashes, {}, struct {
        fn lessThan(_: void, a: u64, b: u64) bool {
            return a < b;
        }
    }.lessThan);

    var sorted_inits: [overloads.len]OverloadInit = overloads;

    std.mem.sort(OverloadInit, &sorted_inits, {}, struct {
        fn lessThan(_: void, a: OverloadInit, b: OverloadInit) bool {
            return Overload.Context.hash(.{}, a.lower()) < Overload.Context.hash(.{}, b.lower());
        }
    }.lessThan);

    var sorted_overloads: [overloads.len]Overload = undefined;
    var sorted_results: [overloads.len]Type = undefined;

    for (sorted_inits, 0..) |data, i| {
        sorted_overloads[i] = data.lower();
        sorted_results[i] = data.result;
    }

    break :blk .{
        .hashes = hashes,
        .results = sorted_results,
        .overloads = sorted_overloads,
    };
};

const overloads = [_]OverloadInit{
    .{
        .kind = .not,
        .operands = &.{.bool},
        .result = .{ .bool = {} },
    },
    .{
        .kind = .not,
        .operands = &.{.{ .vec2 = &.{ .bool = {} } }},
        .result = .{ .vec2 = &.{ .bool = {} } },
    },
    .{
        .kind = .not,
        .operands = &.{.{ .vec3 = &.{ .bool = {} } }},
        .result = .{ .vec3 = &.{ .bool = {} } },
    },
    .{
        .kind = .not,
        .operands = &.{.{ .vec4 = &.{ .bool = {} } }},
        .result = .{ .vec4 = &.{ .bool = {} } },
    },
    .{
        .kind = .cmp_or,
        .operands = &.{ .bool, .bool },
        .result = .{ .bool = {} },
    },
    .{
        .kind = .cmp_and,
        .operands = &.{ .bool, .bool },
        .result = .{ .bool = {} },
    },
    .{
        .kind = .bit_or,
        .operands = &.{ .bool, .bool },
        .result = .{ .bool = {} },
    },
    .{
        .kind = .bit_or,
        .operands = &.{ .bool, .{ .vecN = &.{ .bool = {} } } },
        .result = .{ .vecN = &.{ .bool = {} } },
    },
    .{
        .kind = .bit_or,
        .operands = &.{ .{ .vecN = &.{ .bool = {} } }, .bool },
        .result = .{ .vecN = &.{ .bool = {} } },
    },
    .{
        .kind = .bit_and,
        .operands = &.{ .bool, .bool },
        .result = .{ .bool = {} },
    },
    .{
        .kind = .bit_and,
        .operands = &.{ .{ .vecN = &.{ .bool = {} } }, .bool },
        .result = .{ .vecN = &.{ .bool = {} } },
    },
    .{
        .kind = .bit_and,
        .operands = &.{ .bool, .{ .vecN = &.{ .bool = {} } } },
        .result = .{ .vecN = &.{ .bool = {} } },
    },
    .{
        .kind = .bit_and,
        .operands = &.{ .{ .vecN = &.{ .bool = {} } }, .{ .vecN = &.{ .bool = {} } } },
        .result = .{ .vecN = &.{ .bool = {} } },
    },
    .{
        .kind = .neg,
        .operands = &.{.abstract_int},
        .result = .abstract_int,
    },
    .{
        .kind = .neg,
        .operands = &.{.abstract_float},
        .result = .abstract_float,
    },
    .{
        .kind = .neg,
        .operands = &.{.i32},
        .result = .i32,
    },
    .{
        .kind = .neg,
        .operands = &.{.f32},
        .result = .f32,
    },
    .{
        .kind = .neg,
        .operands = &.{.f16},
        .result = .f16,
    },
    .{
        .kind = .neg,
        .operands = &.{.{ .vecN = &.{ .abstract_int = {} } }},
        .result = .{ .vecN = &.{ .abstract_int = {} } },
    },
    .{
        .kind = .neg,
        .operands = &.{.{ .vecN = &.{ .abstract_float = {} } }},
        .result = .{ .vecN = &.{ .abstract_float = {} } },
    },
    .{
        .kind = .neg,
        .operands = &.{.{ .vecN = &.{ .i32 = {} } }},
        .result = .{ .vecN = &.{ .i32 = {} } },
    },
    .{
        .kind = .neg,
        .operands = &.{.{ .vecN = &.{ .f32 = {} } }},
        .result = .{ .vecN = &.{ .f32 = {} } },
    },
    .{
        .kind = .neg,
        .operands = &.{.{ .vecN = &.{ .f16 = {} } }},
        .result = .{ .vecN = &.{ .f16 = {} } },
    },
    .{
        .kind = .bit_not,
        .operands = &.{.abstract_int},
        .result = .abstract_int,
    },
    .{
        .kind = .bit_not,
        .operands = &.{.i32},
        .result = .i32,
    },
    .{
        .kind = .bit_not,
        .operands = &.{.u32},
        .result = .u32,
    },
    .{
        .kind = .bit_not,
        .operands = &.{.{ .vecN = &.{ .abstract_int = {} } }},
        .result = .abstract_int,
    },
    .{
        .kind = .bit_not,
        .operands = &.{.{ .vecN = &.{ .i32 = {} } }},
        .result = .i32,
    },
    .{
        .kind = .bit_not,
        .operands = &.{.{ .vecN = &.{ .u32 = {} } }},
        .result = .u32,
    },
};

pub const OverloadKind = enum {
    // Operators
    not,
    cmp_or,
    cmp_and,
    bit_or,
    bit_and,
    neg,

    bit_not,

    // Addition, Subtraction, Multiplication, Division, or Modulus all
    // behave the same way.
    arith,

    // Template Builtins
    vec2,
    vec3,
    vec4,

    // Function Call Builtins
    i32,
    u32,
    bool,
    f32,

    vec2_call,
    vec3_call,
    vec4_call,
};

pub const OverloadInit = struct {
    kind: OverloadKind,
    operands: []const Type,
    result: Type,

    pub fn lower(self: OverloadInit) Overload {
        return .{
            .kind = self.kind,
            .operands = self.operands,
        };
    }
};

pub const Overload = struct {
    kind: OverloadKind,
    operands: []const Type,

    pub const Context = struct {
        pub fn hash(_: @This(), op: Overload) u64 {
            var seed = std.hash.Wyhash.init(0);
            seed.update(&.{@intFromEnum(op.kind)});
            for (op.operands) |operand| {
                Type.Context.hashRec(operand, &seed);
            }
            return seed.final();
        }

        pub fn eql(ctx: @This(), a: Overload, b: Overload) bool {
            _ = ctx;
            if (a.kind != b.kind or a.operands.len != b.operands.len) {
                return false;
            }

            if (a.operands.ptr == b.operands.ptr) {
                return true;
            }

            for (a.operands, b.operands) |c, d| {
                if (!Type.Context.eql(.{}, c, d)) {
                    return false;
                }
            }

            return Type.Context.eql(.{}, a.result, b.result);
        }
    };
};
