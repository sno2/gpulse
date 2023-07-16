const std = @import("std");
const ast = @import("ast.zig");
const Node = ast.Node;
const Parser = @import("Parser.zig");
const Lexer = @import("Lexer.zig");
const Trivia = Lexer.Trivia;
const TriviaList = Lexer.TriviaList;
const Fmt = @This();
const Reporter = @import("Reporter.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var file = try std.fs.cwd().readFileAlloc(arena.allocator(), "source.wgsl", 4096);

    var reporter = Reporter.init(arena.allocator());
    _ = reporter.pushSource(file);

    var p = try Parser.init(arena.allocator(), file, &reporter);

    var scope = p.parseGlobalScope() catch &.{};
    try reporter.dump(std.io.getStdErr().writer());

    var fmt = Fmt{ .source = file, .trivias = p.lex.trivias.toOwnedSlice() };

    var stdout = std.io.getStdOut();
    var buffered = std.io.bufferedWriter(stdout.writer());
    var writer = buffered.writer();
    for (scope) |n| {
        try fmt.formatStmt(writer, n, false);
    }

    try buffered.flush();
}

source: []const u8,
level: usize = 0,

idx: u32 = 0,

trivias: TriviaList.Slice,
trivia_idx: u32 = 0,

fn getSpan(fmt: *Fmt, span: ast.Span) []const u8 {
    return fmt.source[span.start..span.end];
}

inline fn indent(fmt: *Fmt) void {
    fmt.level += 1;
}

inline fn dedent(fmt: *Fmt) void {
    fmt.level -= 1;
}

const spaces: [64]u8 = .{' '} ** 64;

inline fn writeIndent(fmt: *const Fmt, writer: anytype) !void {
    var left = fmt.level * 4;

    while (left != 0) {
        var len: usize = @min(64, left);
        try writer.writeAll(spaces[0..len]);
        left -= len;
    }
}

pub fn formatAttributes(fmt: *Fmt, writer: anytype, attrs: []const ast.Attribute) void {
    _ = writer;
    _ = fmt;
    for (attrs) |attr| {
        switch (attr) {}
    }
}

pub fn formatType(fmt: *Fmt, writer: anytype, typ: Node) !void {
    fmt.idx = switch (typ) {
        .identifier => |span| span.start,
        else => fmt.idx,
    };

    try fmt.formatTrivias(writer, .leading_expr);

    switch (typ) {
        .identifier => |span| try writer.writeAll(fmt.getSpan(span)),
        else => std.debug.panic("Unimplemented: {}", .{typ}),
    }
}

pub const TriviaMode = enum {
    stmt,
    leading_expr,
    trailing_expr,
    infix_expr,
};

fn formatTrivias(fmt: *Fmt, writer: anytype, comptime mode: TriviaMode) !void {
    const starts = fmt.trivias.items(.start);

    var last_blank = false;

    while (fmt.trivia_idx < fmt.trivias.len and starts[fmt.trivia_idx] < fmt.idx) : (fmt.trivia_idx += 1) {
        const data = fmt.trivias.get(fmt.trivia_idx);

        switch (data.kind) {
            .block_comment => {
                last_blank = false;

                if (mode == .stmt) {
                    try fmt.writeIndent(writer);
                }
                try writer.writeAll((if (mode == .infix_expr or mode == .trailing_expr) " " else "") ++ "/*");
                try writer.writeAll(fmt.getSpan(ast.Span.init(data.start, data.end)));
                try writer.writeAll("*/" ++ switch (mode) {
                    .stmt => "\n",
                    .leading_expr, .infix_expr => " ",
                    .trailing_expr => "",
                });
            },
            .line_comment => {
                last_blank = false;

                try writer.writeAll("//");
                try writer.writeAll(fmt.getSpan(ast.Span.init(data.start, data.end)));
                try writer.writeAll("\n");

                if (mode != .stmt) {
                    fmt.indent();
                    try fmt.writeIndent(writer);
                    fmt.dedent();
                } else {
                    try fmt.writeIndent(writer);
                }
            },
            .blank_line => {
                if (mode == .stmt and !last_blank) {
                    last_blank = true;
                    try writer.writeAll("\n");
                    try fmt.writeIndent(writer);
                }
            },
        }
    }
}

pub fn formatExpr(fmt: *Fmt, writer: anytype, expr: Node) !void {
    fmt.idx = switch (expr) {
        .err => |span| span.start,
        .identifier => |data| data.start,
        .number_literal => |data| data.span.start,
        .boolean_literal => |data| data.span.start,
        .negate, .not, .bit_not, .deref, .ref => |data| data.op_idx,
        else => fmt.idx,
    };

    try fmt.formatTrivias(writer, .leading_expr);

    switch (expr) {
        .err => |span| try writer.writeAll(fmt.getSpan(span)),
        .identifier => |span| try writer.writeAll(fmt.getSpan(span)),
        .number_literal => |data| try writer.writeAll(fmt.getSpan(data.span)),
        .boolean_literal => |data| try writer.writeAll(fmt.getSpan(data.span)),
        .paren => |data| {
            try writer.writeAll("(");
            try fmt.formatExpr(writer, data.*);
            try writer.writeAll(")");
        },
        inline .negate, .not, .bit_not, .deref, .ref => |data, tag| {
            try writer.writeAll(switch (tag) {
                .negate => "-",
                .not => "!",
                .bit_not => "~",
                .deref => "*",
                .ref => "&",
                else => unreachable,
            });
            try fmt.formatExpr(writer, data.value);
        },
        inline .add, .sub, .mul, .div, .mod, .bit_and, .bit_or, .bit_xor, .bit_left, .bit_right, .cmp_and, .cmp_or, .less_than, .greater_than, .less_than_equal, .greater_than_equal, .equal, .not_equal => |data, tag| {
            try fmt.formatExpr(writer, data.lhs);

            fmt.idx = data.op_idx;
            try fmt.formatTrivias(writer, .trailing_expr);

            try writer.writeAll(" " ++ switch (tag) {
                .add => "+",
                .sub => "-",
                .mul => "*",
                .div => "/",
                .mod => "%",
                .bit_and => "&",
                .bit_or => "|",
                .bit_xor => "^",
                .bit_left => "<<",
                .bit_right => ">>",
                .cmp_and => "&&",
                .cmp_or => "||",
                .less_than => "<",
                .greater_than => ">",
                .less_than_equal => "<=",
                .greater_than_equal => ">=",
                .equal => "==",
                .not_equal => "!=",
                else => unreachable,
            } ++ " ");
            try fmt.formatExpr(writer, data.rhs);
        },
        .call => |data| {
            try fmt.formatExpr(writer, data.callee);
            try writer.writeAll("(");
            for (data.args[0..data.args.len -| 1]) |arg| {
                try fmt.formatExpr(writer, arg);
                try writer.writeAll(", ");
            }
            if (data.args.len != 0) {
                try fmt.formatExpr(writer, data.args[data.args.len - 1]);
            }
            try writer.writeAll(")");
        },
        else => std.debug.panic("Unimplemented: {}", .{expr}),
    }
}

pub const E = error{ AccessDenied, Unexpected, SystemResources, FileTooBig, NoSpaceLeft, DeviceBusy, WouldBlock, InputOutput, OperationAborted, BrokenPipe, ConnectionResetByPeer, DiskQuota, InvalidArgument, NotOpenForWriting, LockViolation };

fn formatScope(fmt: *Fmt, writer: anytype, scope: []const Node) E!void {
    try writer.writeAll(
        if (scope.len != 0)
            " {\n"
        else
            " {",
    );

    fmt.indent();
    for (scope) |n| {
        try fmt.writeIndent(writer);
        try fmt.formatStmt(writer, n, false);
    }
    fmt.dedent();
    if (scope.len != 0) {
        try fmt.writeIndent(writer);
    }
    try writer.writeAll("}");
}

pub fn formatStmt(fmt: *Fmt, writer: anytype, stmt: Node, comptime is_for: bool) E!void {
    fmt.idx = switch (stmt) {
        .fn_decl => |data| data.name.start,
        .var_decl => |data| data.name.start,
        .override_decl => |data| data.name.start,
        .let_decl => |data| data.name.start,
        .const_decl => |data| data.name.start,
        .ret => |data| if (data.value) |v| v.span().start else fmt.idx,
        else => fmt.idx,
    };

    try fmt.formatTrivias(writer, .stmt);

    switch (stmt) {
        .err => |span| {
            try writer.writeAll(fmt.getSpan(span));
            try writer.writeAll("\n");
        },
        .const_decl => |data| {
            try writer.print("const {s}", .{fmt.getSpan(data.name)});

            if (data.typ) |typ| {
                try writer.writeAll(": ");
                try fmt.formatType(writer, typ);
            }

            try writer.writeAll(" = ");
            try fmt.formatExpr(writer, data.value);
            if (!is_for) try writer.writeAll(";\n");
        },
        .let_decl => |data| {
            try writer.print("let {s}", .{fmt.getSpan(data.name)});

            if (data.typ) |typ| {
                try writer.writeAll(": ");
                try fmt.formatType(writer, typ);
            }

            try writer.writeAll(" = ");
            try fmt.formatExpr(writer, data.value);

            if (!is_for) try writer.writeAll(";\n");
        },
        .var_decl => |data| {
            if (data.addr_space != null and data.access_mode != null) {
                try writer.print("var<{s}, {s}> {s}", .{ @tagName(data.addr_space.?), @tagName(data.access_mode.?), fmt.getSpan(data.name) });
            } else if (data.addr_space != null) {
                try writer.print("var<{s}> {s}", .{ @tagName(data.addr_space.?), fmt.getSpan(data.name) });
            } else {
                try writer.print("var {s}", .{fmt.getSpan(data.name)});
            }

            if (data.typ) |typ| {
                try writer.writeAll(": ");
                try fmt.formatType(writer, typ);
            }

            if (data.value) |value| {
                try writer.writeAll(" = ");
                try fmt.formatExpr(writer, value);
            }

            if (!is_for) try writer.writeAll(";\n");
        },
        .fn_decl => |data| {
            try writer.print("fn {s}()", .{fmt.getSpan(data.name)});

            if (data.ret) |ret_t| {
                try writer.writeAll(" -> ");
                try fmt.formatType(writer, ret_t);
            }
            try fmt.formatScope(writer, data.scope);
            try writer.writeAll("\n");
        },
        .ret => |data| {
            if (data.value) |value| {
                try writer.writeAll("return ");
                try fmt.formatExpr(writer, value);
                try writer.writeAll(";\n");
            } else {
                try writer.writeAll("return;\n");
            }
        },
        .call => {
            try fmt.formatExpr(writer, stmt);
            if (!is_for) try writer.writeAll(";\n");
        },
        .inc => |data| {
            try fmt.formatExpr(writer, data.value);

            fmt.idx = data.op_idx;
            try fmt.formatTrivias(writer, .infix_expr);

            try writer.writeAll("++" ++ if (is_for) "" else ";\n");
        },
        .dec => |data| {
            try fmt.formatExpr(writer, data.value);

            fmt.idx = data.op_idx;
            try fmt.formatTrivias(writer, .infix_expr);

            try writer.writeAll("--" ++ if (is_for) "" else ";\n");
        },
        .if_stmt => |data| {
            try writer.writeAll("if ");
            try fmt.formatExpr(writer, data.expression);
            try fmt.formatScope(writer, data.scope);

            if (data.next) |next| {
                try writer.writeAll(if (next.* != .else_stmt) " else " else " else");
                try fmt.formatStmt(writer, next.*, false);
            } else {
                try writer.writeAll("\n");
            }
        },
        .else_stmt => |data| {
            try fmt.formatScope(writer, data.scope);
            try writer.writeAll("\n");
        },
        .for_stmt => |data| {
            try writer.writeAll("for (");
            if (data.init) |init| {
                try fmt.formatStmt(writer, init, true);
            }
            try writer.writeAll("; ");
            if (data.condition) |condition| {
                try fmt.formatExpr(writer, condition);
            }
            try writer.writeAll("; ");
            if (data.update) |update| {
                try fmt.formatStmt(writer, update, true);
            }
            try writer.writeAll(")");
            try fmt.formatScope(writer, data.scope);
            try writer.writeAll("\n");
        },
        .default_selector => try writer.writeAll("default"),
        .switch_stmt => |data| {
            try writer.writeAll("switch ");
            try fmt.formatExpr(writer, data.expression);
            try writer.writeAll(" {\n");
            fmt.indent();
            var default: ?ast.SwitchClause.Default = null;
            for (data.clauses) |clause| {
                switch (clause) {
                    .case => |case| {
                        try fmt.writeIndent(writer);
                        try writer.writeAll("case ");
                        try fmt.formatExpr(writer, case.selectors[0]);
                        try fmt.formatScope(writer, case.scope);
                        try writer.writeAll("\n");
                    },
                    .default => |block| {
                        if (default) |_| {
                            try fmt.writeIndent(writer);
                            try writer.writeAll("default");
                            try fmt.formatScope(writer, block.scope);
                            try writer.writeAll("\n");
                        } else {
                            default = block;
                        }
                    },
                }

                if (default) |block| {
                    try fmt.writeIndent(writer);
                    try writer.writeAll("default");
                    try fmt.formatScope(writer, block.scope);
                    try writer.writeAll("\n");
                }
            }
            fmt.dedent();
            try fmt.writeIndent(writer);
            try writer.writeAll("}\n");
        },
        else => {
            // autofix for expression statements
            try writer.writeAll("_ = ");
            try fmt.formatExpr(writer, stmt);
            try writer.writeAll(";\n");
        },
    }
}
