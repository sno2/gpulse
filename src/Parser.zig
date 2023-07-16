const std = @import("std");
const Lexer = @import("Lexer.zig");
const Token = Lexer.Token;
const ast = @import("ast.zig");
const Span = ast.Span;
const Node = ast.Node;
const Parser = @This();
const CompoundStatement = ast.CompoundStatement;
const Reporter = @import("Reporter.zig");
const Diagnostic = Reporter.Diagnostic;

lex: Lexer,
arena: std.mem.Allocator,
reporter: *Reporter,

pub const AttributeKind = enum {
    unknown,
    attr_align,
    attr_binding,
    attr_builtin,
    attr_const,
    attr_diagnostic,
    attr_group,
    attr_id,
    attr_interpolate,
    attr_invariant,
    attr_location,
    attr_must_use,
    attr_size,
    attr_workgroup_size,
    attr_vertex,
    attr_fragment,
    attr_compute,

    pub const Map = std.ComptimeStringMap(AttributeKind, .{
        .{ "align", .attr_align },
        .{ "binding", .attr_binding },
        .{ "builtin", .attr_builtin },
        .{ "const", .attr_const },
        .{ "diagnostic", .attr_diagnostic },
        .{ "group", .attr_group },
        .{ "id", .attr_id },
        .{ "interpolate", .attr_interpolate },
        .{ "invariant", .attr_invariant },
        .{ "location", .attr_location },
        .{ "must_use", .attr_must_use },
        .{ "size", .attr_size },
        .{ "workgroup_size", .attr_workgroup_size },
        .{ "vertex", .attr_vertex },
        .{ "fragment", .attr_fragment },
        .{ "compute", .attr_compute },
    });
};

pub const Error = error{
    ParseError,
};

pub fn init(arena: std.mem.Allocator, source: []const u8, reporter: *Reporter) !Parser {
    var lex = try Lexer.init(arena, source);
    lex.next();
    return .{
        .lex = lex,
        .arena = arena,
        .reporter = reporter,
    };
}

fn fail(p: *Parser, diagnostic: Diagnostic) Error!noreturn {
    @setCold(true);
    p.reporter.add(diagnostic);
    return error.ParseError;
}

fn report(p: *Parser, diagnostic: Diagnostic) void {
    @setCold(true);
    p.reporter.add(diagnostic);
}

inline fn create(p: *Parser, tag: anytype, data: std.meta.Child(std.meta.TagPayload(Node, tag))) Node {
    @setEvalBranchQuota(5000);
    var ptr = p.arena.create(@TypeOf(data)) catch unreachable;
    ptr.* = data;
    return @unionInit(Node, @tagName(tag), ptr);
}

fn expect(p: *Parser, token: Token) Error!void {
    if (p.lex.token != token) {
        try p.fail(.{
            .span = p.lex.span(),
            .kind = .{ .expected = .{
                .expected = token,
                .got = p.lex.token,
            } },
        });
    }
    p.lex.next();
}

fn expectSemi(p: *Parser) void {
    if (p.lex.token == .t_semi) {
        p.lex.next();
    } else {
        p.report(.{
            .span = p.lex.span(),
            .kind = .{ .expected = .{
                .expected = .t_semi,
                .got = p.lex.token,
            } },
        });
    }
}

fn eat(p: *Parser, token: Token) Error!Span {
    if (p.lex.token != token) {
        try p.fail(.{
            .span = p.lex.span(),
            .kind = .{ .expected = .{
                .expected = token,
                .got = p.lex.token,
            } },
        });
    }
    var span = p.lex.span();
    p.lex.next();
    return span;
}

fn parseType(p: *Parser) Error!Node {
    var name = try p.eat(.t_ident);

    if (p.lex.token != .t_template_start) {
        return Node{ .identifier = name };
    }
    p.lex.next();

    var args = std.ArrayList(Node).initCapacity(p.arena, 1) catch unreachable;

    while (true) {
        var inner = try p.parseExpr();
        args.append(inner) catch unreachable;

        if (p.lex.token == .t_comma) {
            p.lex.next();
        }

        if (p.lex.token == .t_template_end) {
            p.lex.next();
            break;
        }
    }

    return p.create(.template, .{ .name = name, .args = args.toOwnedSlice() catch unreachable });
}

inline fn parseSimpleExpr(p: *Parser) Error!Node {
    switch (p.lex.token) {
        .tk_true => {
            var span = p.lex.span();
            p.lex.next();
            return p.create(.boolean_literal, .{ .span = span });
        },
        .tk_false => {
            var span = p.lex.span();
            p.lex.next();
            return p.create(.boolean_literal, .{ .span = span });
        },
        .t_ident => {
            var span = p.lex.span();
            p.lex.next();
            return Node{ .identifier = span };
        },
        .t_number => {
            var span = p.lex.span();
            var bytes = p.lex.readSpan(span);
            p.lex.next();
            return p.create(.number_literal, .{ .span = span, .kind = switch (bytes[bytes.len - 1]) {
                'i' => ast.NumberLiteral.NumberKind.i32,
                'u' => .u32,
                'f' => .f32,
                'h' => .f16,
                else => if (std.mem.indexOf(u8, bytes, ".") != null)
                    ast.NumberLiteral.NumberKind.abstract_float
                else
                    .abstract_int,
            } });
        },
        .t_lparen => {
            p.lex.next();
            var expr = try p.parseExpr();
            try p.expect(.t_rparen);
            return p.create(.paren, expr);
        },
        .t_sub => {
            const op_idx: u32 = @truncate(p.lex.start);
            p.lex.next();
            return p.create(.negate, .{ .op_idx = op_idx, .value = try p.parseExprRec(5) });
        },
        .t_not => {
            const op_idx: u32 = @truncate(p.lex.start);
            p.lex.next();
            return p.create(.not, .{ .op_idx = op_idx, .value = try p.parseExprRec(5) });
        },
        .t_bit_not => {
            const op_idx: u32 = @truncate(p.lex.start);
            p.lex.next();
            return p.create(.bit_not, .{ .op_idx = op_idx, .value = try p.parseExprRec(5) });
        },
        .t_mul => {
            const op_idx: u32 = @truncate(p.lex.start);
            p.lex.next();
            return p.create(.deref, .{ .op_idx = op_idx, .value = try p.parseExprRec(5) });
        },
        .t_bit_and => {
            const op_idx: u32 = @truncate(p.lex.start);
            p.lex.next();
            return p.create(.ref, .{ .op_idx = op_idx, .value = try p.parseExprRec(5) });
        },
        else => {
            var start = p.lex.start;
            p.report(Diagnostic{
                .span = p.lex.span(),
                .kind = .{ .expected_expression = p.lex.token },
            });

            // Hopefully recover.
            while (true) {
                if (p.lex.has_newline_before) break;
                switch (p.lex.token) {
                    .t_eof => break,
                    .t_semi => {
                        p.lex.next();
                        break;
                    },
                    else => p.lex.next(),
                }
            }

            return Node{
                .err = Span.init(@truncate(start), @truncate(p.lex.start)),
            };
        },
    }
}

// https://www.w3.org/TR/WGSL/#operator-precedence-associativity
fn lbp(token: Token) u8 {
    return switch (token) {
        .t_template_start => 7,
        .t_lparen, .t_lbrack, .t_dot => 6,
        // unary operators => 5
        .t_bit_xor, .t_bit_or, .t_bit_and, .t_mul, .t_div, .t_mod => 4,
        .t_bit_left, .t_bit_right => 4,
        .t_add, .t_sub => 3,
        .t_greater_than, .t_greater_than_equal, .t_less_than, .t_less_than_equal, .t_equality, .t_not_equal => 2,
        .t_and, .t_or => 1,
        else => 0,
    };
}

const Assoc = enum {
    ltr,
    none,
};

fn assoc(token: Token) Assoc {
    return switch (token) {
        .t_lparen, .t_lbrack, .t_dot => .ltr,
        // unary operators => 5
        .t_bit_xor, .t_bit_or, .t_bit_and, .t_mul, .t_div, .t_mod => .ltr,
        .t_bit_left, .t_bit_right => .none,
        .t_add, .t_sub => .ltr,
        .t_greater_than, .t_greater_than_equal, .t_less_than, .t_less_than_equal, .t_equality, .t_not_equal => .none,
        .t_and, .t_or => .ltr,
        else => .none,
    };
}

fn parseExprRec(p: *Parser, hp: u8) Error!Node {
    var lhs = try p.parseSimpleExpr();

    while (true) {
        var ass = assoc(p.lex.token);
        var power = lbp(p.lex.token);

        if (ass == .none and power <= hp or ass == .ltr and power < hp) {
            break;
        }

        switch (p.lex.token) {
            inline .t_add,
            .t_sub,
            .t_mul,
            .t_div,
            .t_mod,
            .t_bit_left,
            .t_bit_right,
            .t_bit_and,
            .t_bit_or,
            .t_bit_xor,
            .t_less_than,
            .t_less_than_equal,
            .t_greater_than,
            .t_greater_than_equal,
            .t_not_equal,
            => |tag| {
                const op_idx: u32 = @truncate(p.lex.start);
                p.lex.next();
                lhs = p.create(@field(ast.NodeTag, @tagName(tag)[2..]), .{
                    .lhs = lhs,
                    .op_idx = op_idx,
                    .rhs = try p.parseExprRec(power),
                });
            },
            .t_dot => {
                const op_idx: u32 = @truncate(p.lex.start);
                p.lex.next();
                lhs = p.create(.member, .{
                    .lhs = lhs,
                    .op_idx = op_idx,
                    .rhs = try p.parseExprRec(power),
                });
            },
            .t_or => {
                const op_idx: u32 = @truncate(p.lex.start);
                p.lex.next();
                lhs = p.create(.cmp_or, .{
                    .lhs = lhs,
                    .op_idx = op_idx,
                    .rhs = try p.parseExprRec(power),
                });
            },
            .t_and => {
                const op_idx: u32 = @truncate(p.lex.start);
                p.lex.next();
                lhs = p.create(.cmp_and, .{
                    .lhs = lhs,
                    .op_idx = op_idx,
                    .rhs = try p.parseExprRec(power),
                });
            },
            .t_equality => {
                const op_idx: u32 = @truncate(p.lex.start);
                p.lex.next();
                lhs = p.create(.equal, .{
                    .lhs = lhs,
                    .op_idx = op_idx,
                    .rhs = try p.parseExprRec(power),
                });
            },
            .t_lbrack => {
                p.lex.next();
                lhs = p.create(.index, .{
                    .root = lhs,
                    .index = try p.parseExpr(),
                });
                try p.expect(.t_rbrack);
            },
            .t_lparen => {
                p.lex.next();
                var args = std.ArrayList(Node).init(p.arena);
                while (true) {
                    if (p.lex.token == .t_rparen) {
                        break;
                    }
                    args.append(try p.parseExpr()) catch unreachable;
                    if (p.lex.token != .t_comma) {
                        break;
                    }
                    p.lex.next();
                }
                try p.expect(.t_rparen);
                lhs = p.create(.call, .{
                    .callee = lhs,
                    .args = args.toOwnedSlice() catch unreachable,
                });
            },
            .t_template_start => {
                p.lex.next();

                var args = std.ArrayList(Node).init(p.arena);

                while (true) {
                    if (p.lex.token == .t_template_end) break;

                    var value = try p.parseExpr();
                    args.append(value) catch unreachable;

                    if (p.lex.token != .t_comma) break;
                    p.lex.next();
                }

                try p.expect(.t_template_end);
                lhs = p.create(.template, .{
                    .name = switch (lhs) {
                        .identifier => |ident| ident,
                        else => blk: {
                            p.report(Diagnostic{
                                .span = lhs.span(),
                                .kind = .{ .expected_ident_template = {} },
                            });
                            break :blk Span.zero;
                        },
                    },
                    .args = args.toOwnedSlice() catch unreachable,
                });
            },
            else => break,
        }
    }

    return lhs;
}

inline fn parseExpr(p: *Parser) Error!Node {
    return p.parseExprRec(0);
}

/// Parses a list of attributes after the leading `@`.
fn parseAttributeList(p: *Parser) Error![]ast.Attribute {
    var items = std.ArrayList(ast.Attribute).initCapacity(p.arena, 1) catch unreachable;

    while (true) {
        switch (p.lex.token) {
            .t_ident, .tk_const, .tk_diagnostic => {},
            else => try p.expect(.t_ident),
        }

        var attr_name_span = p.lex.span();
        var attr_name = p.lex.readSpan(attr_name_span);
        var kind = AttributeKind.Map.get(attr_name);
        p.lex.next();

        switch (kind orelse .unknown) {
            // Attributes without arguments.
            inline .attr_const, .attr_invariant, .attr_must_use, .attr_vertex, .attr_fragment, .attr_compute => |tag| {
                items.append(@unionInit(ast.Attribute, @tagName(tag)["attr_".len..], {})) catch unreachable;

                if (p.lex.token != .t_at) {
                    break;
                }
                p.lex.next();
                continue;
            },
            .attr_align => {
                try p.expect(.t_lparen);
                var expr = try p.parseExpr();
                items.append(.{ .@"align" = expr }) catch unreachable;
            },
            .attr_binding => {
                try p.expect(.t_lparen);
                var expr = try p.parseExpr();
                items.append(.{ .binding = expr }) catch unreachable;
            },
            .attr_builtin => {
                try p.expect(.t_lparen);
                var expr = try p.parseExpr();
                items.append(.{ .builtin = expr }) catch unreachable;
            },
            .attr_diagnostic => {
                var data = try p.parseDiagnosticControl();
                items.append(.{ .diagnostic = data }) catch unreachable;

                if (p.lex.token != .t_at) break;
                p.lex.next();
                continue;
            },
            .attr_group => {
                try p.expect(.t_lparen);
                var expr = try p.parseExpr();
                items.append(.{ .group = expr }) catch unreachable;
            },
            .attr_id => {
                try p.expect(.t_lparen);
                var expr = try p.parseExpr();
                items.append(.{ .id = expr }) catch unreachable;
            },
            .attr_interpolate => {
                try p.expect(.t_lparen);
                var data = ast.InterpolateAttribute{
                    .first = try p.parseExpr(),
                    .second = if (p.lex.token == .t_comma) blk: {
                        p.lex.next();
                        break :blk try p.parseExpr();
                    } else null,
                };
                items.append(.{ .interpolate = data }) catch unreachable;
            },
            .attr_location => {
                try p.expect(.t_lparen);
                var expr = try p.parseExpr();
                items.append(.{ .location = expr }) catch unreachable;
            },
            .attr_size => {
                try p.expect(.t_lparen);
                var expr = try p.parseExpr();
                items.append(.{ .size = expr }) catch unreachable;
            },
            .attr_workgroup_size => {
                try p.expect(.t_lparen);
                var x = try p.parseExpr();
                var y: ?Node = null;
                var z: ?Node = null;

                if (p.lex.token == .t_comma) blk: {
                    p.lex.next();
                    if (p.lex.token == .t_rparen) break :blk;
                    y = try p.parseExpr();

                    if (p.lex.token != .t_comma) break :blk;
                    p.lex.next();
                    if (p.lex.token == .t_rparen) break :blk;
                    z = try p.parseExpr();

                    if (p.lex.token == .t_comma) p.lex.next();
                }

                items.append(.{ .workgroup_size = .{ .x = x, .y = y, .z = z } }) catch unreachable;
            },
            .unknown => {
                p.report(Diagnostic{
                    .span = attr_name_span,
                    .kind = .{ .unknown_attribute_name = attr_name },
                });

                // Skip any syntax we don't understand.
                if (p.lex.token == .t_lparen) {
                    var open: usize = 1;

                    while (true) {
                        p.lex.next();
                        switch (p.lex.token) {
                            .t_lparen => open += 1,
                            .t_rparen => {
                                open -= 1;
                                if (open == 0) {
                                    p.lex.next();
                                    break;
                                }
                            },
                            else => {},
                        }
                    }
                }

                if (p.lex.token != .t_at) break;
                p.lex.next();
                continue;
            },
        }

        if (p.lex.token == .t_comma) {
            p.lex.next();
        }
        try p.expect(.t_rparen);

        if (p.lex.token != .t_at) {
            break;
        }
        p.lex.next();
    }

    return items.toOwnedSlice() catch unreachable;
}

/// Parses an extension list after the `enable` or `requires` keyword.
fn parseExtensionList(p: *Parser) Error![]Span {
    var names = std.ArrayList(Span).initCapacity(p.arena, 1) catch unreachable;
    while (true) {
        var name = try p.eat(.t_ident);
        names.append(name) catch unreachable;

        if (p.lex.token == .t_semi) {
            p.lex.next();
            break;
        }
        try p.expect(.t_comma);
    }
    return names.toOwnedSlice() catch unreachable;
}

inline fn maybeParseAttributeList(p: *Parser) !?[]ast.Attribute {
    if (p.lex.token == .t_at) {
        p.lex.next();
        return try p.parseAttributeList();
    } else {
        return null;
    }
}

/// https://www.w3.org/TR/WGSL/#syntax-diagnostic_control
fn parseDiagnosticControl(p: *Parser) Error!ast.DiagnosticControl {
    try p.expect(.t_lparen);

    var severity_span = try p.eat(.t_ident);
    var severity = ast.SeverityControlName.Map.get(p.lex.source[severity_span.start..severity_span.end]) orelse blk: {
        p.report(Diagnostic{
            .span = severity_span,
            .kind = .invalid_severity_name,
        });
        break :blk .unknown;
    };

    try p.expect(.t_comma);

    var first_name = try p.eat(.t_ident);

    var second_name = Span.zero;
    if (p.lex.token == .t_dot) {
        p.lex.next();
        second_name = first_name;
        first_name = try p.eat(.t_ident);
    }

    if (p.lex.token == .t_comma) {
        p.lex.next();
    }

    try p.expect(.t_rparen);

    return ast.DiagnosticControl{
        .severity = severity,
        .rule_namespace = second_name,
        .rule_name = first_name,
    };
}

pub const ScopeContext = struct {
    is_function: bool = false,
    is_loop: bool = false,
};

/// Parses a typed label which may have attributes.
fn parseTypedLabel(p: *Parser) !Node {
    var attributes = try p.maybeParseAttributeList();
    var p_name = try p.eat(.t_ident);
    try p.expect(.t_colon);
    var p_type = try p.parseType();

    var node = p.create(.labeled_type, .{
        .name = p_name,
        .typ = p_type,
    });

    if (attributes) |attrs| {
        node = p.create(.attributed, .{
            .attributes = attrs,
            .inner = node,
        });
    }

    return node;
}

/// https://www.w3.org/TR/WGSL/#recursive-descent-syntax-compound_statement
inline fn parseCompoundStmt(p: *Parser, ctx: ScopeContext) !CompoundStatement {
    var attributes = try p.maybeParseAttributeList();
    try p.expect(.t_lbrace);
    var scope = try p.parseScope(ctx);
    try p.expect(.t_rbrace);
    return CompoundStatement{ .attributes = attributes, .scope = scope };
}

/// https://www.w3.org/TR/WGSL/#syntax-variable_updating_statement
///
/// Parses a variable updating statement without eating a terminating
/// semi-colon.
inline fn parseVariableUpdating(p: *Parser) !Node {
    if (p.lex.token == .t_under) {
        p.lex.next();
        try p.expect(.t_assign);
        return p.create(.phony, .{ .value = try p.parseExpr() });
    }

    var binding = try p.parseExpr();

    switch (p.lex.token) {
        inline .t_assign, .t_add_assign, .t_sub_assign, .t_mul_assign, .t_div_assign, .t_mod_assign, .t_bit_left_assign, .t_bit_right_assign, .t_bit_and_assign, .t_bit_or_assign, .t_bit_xor_assign => |tag| {
            const op_idx: u32 = @truncate(p.lex.start);
            p.lex.next();
            var value = try p.parseExpr();
            return p.create(@field(ast.NodeTag, @tagName(tag)[2..]), .{
                .lhs = binding,
                .op_idx = op_idx,
                .rhs = value,
            });
        },
        .t_inc => {
            const op_idx: u32 = @truncate(p.lex.start);
            p.lex.next();
            return p.create(.inc, .{ .op_idx = op_idx, .value = binding });
        },
        .t_dec => {
            const op_idx: u32 = @truncate(p.lex.start);
            p.lex.next();
            return p.create(.dec, .{ .op_idx = op_idx, .value = binding });
        },
        else => {
            // Technically we aren't supposed to parse this here...but it's
            // easier to just do it now.
            if (binding != .call) {
                p.reporter.add(Diagnostic{ .span = p.lex.span(), .kind = .{
                    .invalid_expr_statement = {},
                } });
            }
            return binding;
        },
    }
}

/// https://www.w3.org/TR/WGSL/#syntax-variable_or_value_statement
///
/// Parses a variable or value declaration without eating a terminating
/// semi-colon.
inline fn parseVariableDecl(p: *Parser, ctx: ScopeContext) !Node {
    switch (p.lex.token) {
        .tk_var => {
            p.lex.next();

            var access_mode: ?ast.AccessMode = null;
            var addr_space: ?ast.AddrSpace = null;

            if (p.lex.token == .t_template_start) {
                p.lex.next();
                var first = try p.eat(.t_ident);
                addr_space = ast.AddrSpace.Map.get(p.lex.readSpan(first));

                if (p.lex.token == .t_comma) blk: {
                    p.lex.next();
                    if (p.lex.token == .t_template_end)
                        break :blk;
                    var second = try p.eat(.t_ident);
                    access_mode = ast.AccessMode.Map.get(p.lex.readSpan(second)) orelse .read;
                }
                try p.expect(.t_template_end);
            }

            var name = try p.eat(.t_ident);

            var typ = if (p.lex.token == .t_colon) blk: {
                p.lex.next();
                break :blk try p.parseType();
            } else null;

            var value: ?Node = if (p.lex.token == .t_assign) blk: {
                p.lex.next();
                break :blk try p.parseExpr();
            } else null;

            return p.create(.var_decl, .{
                .name = name,
                .access_mode = access_mode,
                .addr_space = addr_space,
                .typ = typ,
                .value = value,
            });
        },
        .tk_let => {
            var start = p.lex.start;
            p.lex.next();
            var name = try p.eat(.t_ident);
            var typ = if (p.lex.token == .t_colon) blk: {
                p.lex.next();
                break :blk try p.parseType();
            } else null;
            try p.expect(.t_assign);
            var value = try p.parseExpr();

            if (!ctx.is_function) {
                var end: u32 = @truncate(if (p.lex.token == .t_semi) p.lex.index else p.lex.start);
                p.reporter.add(Diagnostic{
                    .span = Span.init(@truncate(start), end),
                    .kind = .invalid_let_statement,
                });
                return .{ .err = Span.init(@truncate(start), end) };
            }

            return p.create(.let_decl, .{
                .name = name,
                .typ = typ,
                .value = value,
            });
        },
        .tk_const => {
            p.lex.next();
            var name = try p.eat(.t_ident);
            var typ = if (p.lex.token == .t_colon) blk: {
                p.lex.next();
                break :blk try p.parseType();
            } else null;
            try p.expect(.t_assign);
            var value = try p.parseExpr();
            return p.create(.const_decl, .{ .name = name, .typ = typ, .value = value });
        },
        .tk_override => {
            var start = p.lex.start;
            p.lex.next();
            var name = try p.eat(.t_ident);
            var typ = if (p.lex.token == .t_colon) blk: {
                p.lex.next();
                break :blk try p.parseType();
            } else null;
            var value = if (p.lex.token == .t_assign) blk: {
                p.lex.next();
                break :blk try p.parseExpr();
            } else null;

            if (ctx.is_function) blk: {
                var end: u32 = if (p.lex.token == .t_semi)
                    @truncate(p.lex.index)
                else if (value) |v|
                    v.span().end
                else if (typ) |t|
                    t.span().end
                else
                    break :blk;

                p.reporter.add(Diagnostic{
                    .span = Span.init(@truncate(start), end),
                    .kind = .{ .invalid_override_statement = {} },
                });
                p.expectSemi();
                return .{ .err = Span.init(@truncate(start), end) };
            }

            return p.create(.override_decl, .{ .name = name, .typ = typ, .value = value });
        },
        else => unreachable,
    }
}

/// Parse a single statement.
pub fn parseStmt(p: *Parser, ctx: ScopeContext) Error!Node {
    switch (p.lex.token) {
        .t_lbrace => {
            p.lex.next();
            var scope = try p.parseScope(ctx);
            try p.expect(.t_rbrace);
            return p.create(.scope, .{ .scope = scope });
        },
        .tk_enable => {
            p.lex.next();
            var names = try p.parseExtensionList();
            return p.create(.enable_directive, .{ .names = names });
        },
        .tk_requires => {
            p.lex.next();
            var names = try p.parseExtensionList();
            return p.create(.requires_directive, .{ .names = names });
        },
        .tk_diagnostic => {
            p.lex.next();
            var control = try p.parseDiagnosticControl();
            p.expectSemi();
            return p.create(.diagnostic_directive, control);
        },
        // https://www.w3.org/TR/WGSL/#type-aliases
        .tk_alias => {
            var start = @as(u32, @truncate(p.lex.start));
            p.lex.next();
            var name = try p.eat(.t_ident);
            try p.expect(.t_assign);
            var typ = try p.parseType();
            if (ctx.is_function) {
                p.report(Diagnostic{ .span = Span{
                    .start = start,
                    .end = @as(u32, @truncate(p.lex.index)),
                }, .kind = .invalid_type_alias });
            }
            p.expectSemi();

            return p.create(.type_alias, .{ .name = name, .value = typ });
        },
        .t_at => {
            p.lex.next();
            var attributes = try p.parseAttributeList();
            var stmt = try p.parseStmt(ctx);
            return p.create(.attributed, .{ .attributes = attributes, .inner = stmt });
        },
        // https://www.w3.org/TR/WGSL/#discard-statement
        .tk_discard => {
            var span = p.lex.span();
            p.lex.next();
            p.expectSemi();
            return Node{ .discard = span };
        },
        // https://www.w3.org/TR/WGSL/#syntax-const_assert_statement
        .tk_const_assert => {
            p.lex.next();
            var value = try p.parseExpr();
            return p.create(.const_assert, .{ .value = value });
        },
        .tk_return => {
            p.lex.next();
            if (p.lex.token != .t_semi) {
                var value = try p.parseExpr();
                p.expectSemi();
                return p.create(.ret, .{ .value = value });
            }
            p.expectSemi();
            return p.create(.ret, .{ .value = null });
        },
        .tk_var, .tk_let, .tk_const, .tk_override => {
            var node = try p.parseVariableDecl(ctx);
            p.expectSemi();
            return node;
        },
        .tk_struct => {
            p.lex.next();
            var name = try p.eat(.t_ident);
            try p.expect(.t_lbrace);

            var members = std.ArrayList(Node).init(p.arena);
            while (p.lex.token != .t_rbrace) {
                members.append(try p.parseTypedLabel()) catch unreachable;

                if (p.lex.token != .t_comma) {
                    break;
                }
                p.lex.next();
            }
            try p.expect(.t_rbrace);

            return p.create(.struct_decl, .{
                .name = name,
                .members = members.toOwnedSlice() catch unreachable,
            });
        },
        .tk_fn => {
            p.lex.next();
            var name = try p.eat(.t_ident);
            try p.expect(.t_lparen);

            var params = std.ArrayList(Node).init(p.arena);

            while (p.lex.token != .t_rparen) {
                params.append(try p.parseTypedLabel()) catch unreachable;

                if (p.lex.token != .t_comma) {
                    break;
                }
                p.lex.next();
            }

            try p.expect(.t_rparen);

            var ret: ?Node = null;

            if (p.lex.token == .t_thin_arrow) {
                p.lex.next();
                if (p.lex.token == .t_at) {
                    p.lex.next();
                    var attributes = try p.parseAttributeList();
                    ret = p.create(.attributed, .{
                        .attributes = attributes,
                        .inner = try p.parseType(),
                    });
                } else {
                    ret = try p.parseType();
                }
            }

            try p.expect(.t_lbrace);
            var scope = try p.parseScope(ScopeContext{
                .is_function = true,
            });
            try p.expect(.t_rbrace);
            return p.create(.fn_decl, .{
                .name = name,
                .params = params.toOwnedSlice() catch unreachable,
                .ret = ret,
                .scope = scope,
            });
        },
        .tk_loop => {
            p.lex.next();
            var data = try p.parseCompoundStmt(ctx);
            return p.create(.loop, .{ .attributes = data.attributes, .scope = data.scope });
        },
        .tk_switch => {
            p.lex.next();
            var expression = try p.parseExpr();
            var attributes = try p.maybeParseAttributeList();
            try p.expect(.t_lbrace);

            var clauses = std.ArrayList(ast.SwitchClause).init(p.arena);
            while (true) {
                switch (p.lex.token) {
                    .tk_case => {
                        p.lex.next();
                        var selectors = std.ArrayList(Node).initCapacity(p.arena, 1) catch unreachable;

                        while (true) {
                            if (p.lex.token == .tk_default) {
                                selectors.append(Node{ .default_selector = p.lex.span() }) catch unreachable;
                                p.lex.next();
                            } else {
                                selectors.append(try p.parseExpr()) catch unreachable;
                            }

                            if (p.lex.token != .t_comma) break;
                            p.lex.next();

                            switch (p.lex.token) {
                                .t_colon, .t_lbrace, .t_at => break,
                                else => {},
                            }
                        }

                        if (p.lex.token == .t_colon) p.lex.next();

                        var data = try p.parseCompoundStmt(ctx);

                        clauses.append(.{ .case = .{
                            .selectors = selectors.toOwnedSlice() catch unreachable,
                            .attributes = data.attributes,
                            .scope = data.scope,
                        } }) catch unreachable;
                    },
                    .tk_default => {
                        p.lex.next();
                        if (p.lex.token == .t_colon) {
                            p.lex.next();
                        }

                        var data = try p.parseCompoundStmt(ctx);
                        clauses.append(.{ .default = .{ .attributes = data.attributes, .scope = data.scope } }) catch unreachable;
                    },
                    .t_rbrace => break,
                    else => try p.fail(Diagnostic{
                        .span = p.lex.span(),
                        .kind = .{ .expected_switch_clause = p.lex.token },
                    }),
                }
            }

            try p.expect(.t_rbrace);
            return p.create(.switch_stmt, .{
                .expression = expression,
                .attributes = attributes,
                .clauses = clauses.toOwnedSlice() catch unreachable,
            });
        },
        .tk_if => {
            var head: Node = undefined;
            var cur: ?*Node = &head;

            while (true) {
                if (p.lex.token == .t_lbrace) {
                    var data = try p.parseCompoundStmt(ctx);
                    cur.?.* = p.create(.else_stmt, .{
                        .attributes = data.attributes,
                        .scope = data.scope,
                    });
                    break;
                }

                try p.expect(.tk_if);

                var expr = try p.parseExpr();
                var data = try p.parseCompoundStmt(ctx);

                var next: ?*Node = if (p.lex.token != .tk_else) null else p.arena.create(Node) catch unreachable;
                cur.?.* = p.create(.if_stmt, .{
                    .expression = expr,
                    .attributes = data.attributes,
                    .scope = data.scope,
                    .next = next,
                });
                cur = next;

                if (p.lex.token != .tk_else) {
                    break;
                }

                p.lex.next();
            }

            return head;
        },
        .tk_continuing => {
            p.lex.next();
            var compound_stmt = try p.parseCompoundStmt(ctx);
            return p.create(.continuing, compound_stmt);
        },
        .tk_continue => {
            var span = p.lex.span();
            p.lex.next();
            try p.expect(.t_semi);
            return Node{ .cont = span };
        },
        .tk_break => {
            var span = p.lex.span();
            p.lex.next();

            if (p.lex.token == .t_semi) {
                p.lex.next();
                return Node{ .brk = span };
            }

            try p.expect(.tk_if);

            var node = try p.parseExpr();
            return p.create(.break_if, .{ .value = node });
        },
        .tk_for => {
            p.lex.next();
            try p.expect(.t_lparen);
            var for_init = switch (p.lex.token) {
                .t_semi => null,
                .tk_let, .tk_var, .tk_const, .tk_override => try p.parseVariableDecl(ctx),
                else => try p.parseVariableUpdating(),
            };
            try p.expect(.t_semi);
            var for_cond = if (p.lex.token == .t_semi) null else try p.parseExpr();
            try p.expect(.t_semi);
            var for_update = switch (p.lex.token) {
                .t_rparen => null,
                else => try p.parseVariableUpdating(),
            };
            try p.expect(.t_rparen);
            var scope = try p.parseCompoundStmt(ScopeContext{
                .is_function = true,
                .is_loop = true,
            });
            return p.create(.for_stmt, .{
                .init = for_init,
                .condition = for_cond,
                .update = for_update,
                .attributes = scope.attributes,
                .scope = scope.scope,
            });
        },
        .tk_while => {
            p.lex.next();

            var expression = try p.parseExpr();
            var data = try p.parseCompoundStmt(ctx);

            return p.create(.while_stmt, .{
                .expression = expression,
                .attributes = data.attributes,
                .scope = data.scope,
            });
        },
        else => {
            var node = try p.parseVariableUpdating();
            p.expectSemi();
            return node;
        },
    }
}

pub fn parseGlobalScope(p: *Parser) Error![]Node {
    var nodes = std.ArrayList(Node).init(p.arena);
    var ctx = ScopeContext{};

    while (true) {
        switch (p.lex.token) {
            .t_semi => p.lex.next(),
            .t_eof => break,
            else => nodes.append(try p.parseStmt(ctx)) catch unreachable,
        }
    }

    return nodes.toOwnedSlice() catch unreachable;
}

pub fn parseScope(p: *Parser, ctx: ScopeContext) Error![]Node {
    var nodes = std.ArrayList(Node).init(p.arena);

    while (true) {
        switch (p.lex.token) {
            .t_semi => p.lex.next(),
            .t_eof => break,
            .t_rbrace => {
                if (!ctx.is_function) {
                    p.reporter.add(Diagnostic{
                        .span = p.lex.span(),
                        .kind = .{ .expected_statement = .t_rbrace },
                    });
                }
                break;
            },
            else => nodes.append(try p.parseStmt(ctx)) catch unreachable,
        }
    }

    return nodes.toOwnedSlice() catch unreachable;
}
