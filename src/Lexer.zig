const std = @import("std");
const Lexer = @This();
const Span = @import("ast.zig").Span;
const discovery = @import("discovery.zig");

pub const Token = enum {
    // End of file
    t_eof,

    // Atoms
    t_ident,
    t_number,
    t_comment,
    t_true,
    t_false,

    // Symbols/Operators
    t_at,
    t_thin_arrow,
    t_lparen,
    t_rparen,
    t_lbrace,
    t_rbrace,
    t_add,
    t_sub,
    t_mul,
    t_div,

    // https://www.w3.org/TR/WGSL/#keyword-summary
    tk_alias,
    tk_break,
    tk_case,
    tk_const,
    tk_const_assert,
    tk_continue,
    tk_continuing,
    tk_default,
    tk_diagnostic,
    tk_discard,
    tk_else,
    tk_enable,
    tk_false,
    tk_fn,
    tk_for,
    tk_if,
    tk_let,
    tk_loop,
    tk_override,
    tk_requires,
    tk_return,
    tk_struct,
    tk_switch,
    tk_true,
    tk_var,
    tk_while,

    // https://www.w3.org/TR/WGSL/#reserved-words
    t_reserved,

    // https://www.w3.org/TR/WGSL/#syntactic-tokens
    t_bit_and,
    t_and,
    t_bit_and_assign,
    t_dec,
    t_sub_assign,
    t_div_assign,
    t_not,
    t_colon,
    t_rbrack,
    t_lbrack,
    t_comma,
    t_not_equal,
    t_equality,
    t_assign,
    t_greater_than,
    t_greater_than_equal,
    t_bit_right,
    t_bit_right_assign,
    t_less_than_equal,
    t_bit_left_assign,
    t_bit_left,
    t_less_than,
    t_mod,
    t_mod_assign,
    t_dot,
    t_inc,
    t_add_assign,
    t_or,
    t_bit_or_assign,
    t_bit_or,
    t_semi,
    t_mul_assign,
    t_bit_not,
    t_under,
    t_bit_xor_assign,
    t_bit_xor,

    t_template_start,
    t_template_end,

    t_unknown,

    pub fn format(token: Token, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        try writer.writeAll(switch (token) {
            .t_eof => "end of file",
            .t_ident => "an identifier",
            .t_number => "a number",
            .t_comment => "a comment",
            .t_true => "'true'",
            .t_false => "'false'",
            .t_at => "'@'",
            .t_thin_arrow => "'->'",
            .t_lparen => "'('",
            .t_rparen => "')'",
            .t_lbrace => "'{'",
            .t_rbrace => "'}'",
            .t_add => "'+'",
            .t_sub => "'-'",
            .t_mul => "'*'",
            .t_div => "'/'",
            .tk_alias => "'alias'",
            .tk_break => "'break'",
            .tk_case => "'case'",
            .tk_const => "'const'",
            .tk_const_assert => "'const_assert'",
            .tk_continue => "'continue'",
            .tk_continuing => "'continuing'",
            .tk_default => "'default'",
            .tk_diagnostic => "'diagnostic'",
            .tk_discard => "'discard'",
            .tk_else => "'else'",
            .tk_enable => "'enable'",
            .tk_false => "'false'",
            .tk_fn => "'fn'",
            .tk_for => "'for'",
            .tk_if => "'if'",
            .tk_let => "'let'",
            .tk_loop => "'loop'",
            .tk_override => "'override'",
            .tk_requires => "'requires'",
            .tk_return => "'return'",
            .tk_struct => "'struct'",
            .tk_switch => "'switch'",
            .tk_true => "'true'",
            .tk_var => "'var'",
            .tk_while => "'while'",
            .t_reserved => "a reserved word",
            .t_bit_and => "'&'",
            .t_and => "'&&'",
            .t_bit_and_assign => "'&='",
            .t_dec => "'--'",
            .t_sub_assign => "'-='",
            .t_div_assign => "'/='",
            .t_not => "'!'",
            .t_colon => "':'",
            .t_rbrack => "']'",
            .t_lbrack => "'['",
            .t_comma => "','",
            .t_not_equal => "'!='",
            .t_equality => "'=='",
            .t_assign => "'='",
            .t_greater_than => "'>'",
            .t_greater_than_equal => "'>='",
            .t_bit_right => "'>>'",
            .t_bit_right_assign => "'>>='",
            .t_less_than_equal => "'<='",
            .t_bit_left_assign => "'<<='",
            .t_bit_left => "'<<'",
            .t_less_than => "'<'",
            .t_mod => "'%'",
            .t_mod_assign => "'%='",
            .t_dot => "'.'",
            .t_inc => "'++'",
            .t_add_assign => "'+='",
            .t_or => "'||'",
            .t_bit_or_assign => "'|='",
            .t_bit_or => "'|'",
            .t_semi => "';'",
            .t_mul_assign => "'*='",
            .t_bit_not => "'~'",
            .t_under => "'_'",
            .t_bit_xor_assign => "'^='",
            .t_bit_xor => "'^'",
            .t_template_start => "'<'",
            .t_template_end => "'>'",
            .t_unknown => "unknown character",
        });
    }
};

pub const interesting = blk: {
    @setEvalBranchQuota(5000);
    break :blk std.ComptimeStringMap(Token, .{
        // https://www.w3.org/TR/WGSL/#keyword-summary
        .{ "alias", .tk_alias },
        .{ "break", .tk_break },
        .{ "case", .tk_case },
        .{ "const", .tk_const },
        .{ "const_assert", .tk_const_assert },
        .{ "continue", .tk_continue },
        .{ "continuing", .tk_continuing },
        .{ "default", .tk_default },
        .{ "diagnostic", .tk_diagnostic },
        .{ "discard", .tk_discard },
        .{ "else", .tk_else },
        .{ "enable", .tk_enable },
        .{ "false", .tk_false },
        .{ "fn", .tk_fn },
        .{ "for", .tk_for },
        .{ "if", .tk_if },
        .{ "let", .tk_let },
        .{ "loop", .tk_loop },
        .{ "override", .tk_override },
        .{ "requires", .tk_requires },
        .{ "return", .tk_return },
        .{ "struct", .tk_struct },
        .{ "switch", .tk_switch },
        .{ "true", .tk_true },
        .{ "var", .tk_var },
        .{ "while", .tk_while },

        // https://www.w3.org/TR/WGSL/#reserved-words
        .{ "NULL", .t_reserved },
        .{ "Self", .t_reserved },
        .{ "abstract", .t_reserved },
        .{ "active", .t_reserved },
        .{ "alignas", .t_reserved },
        .{ "alignof", .t_reserved },
        .{ "as", .t_reserved },
        .{ "asm", .t_reserved },
        .{ "asm_fragment", .t_reserved },
        .{ "async", .t_reserved },
        .{ "attribute", .t_reserved },
        .{ "auto", .t_reserved },
        .{ "await", .t_reserved },
        .{ "become", .t_reserved },
        .{ "binding_array", .t_reserved },
        .{ "cast", .t_reserved },
        .{ "catch", .t_reserved },
        .{ "class", .t_reserved },
        .{ "co_await", .t_reserved },
        .{ "co_return", .t_reserved },
        .{ "co_yield", .t_reserved },
        .{ "coherent", .t_reserved },
        .{ "column_major", .t_reserved },
        .{ "common", .t_reserved },
        .{ "compile", .t_reserved },
        .{ "compile_fragment", .t_reserved },
        .{ "concept", .t_reserved },
        .{ "const_cast", .t_reserved },
        .{ "consteval", .t_reserved },
        .{ "constexpr", .t_reserved },
        .{ "constinit", .t_reserved },
        .{ "crate", .t_reserved },
        .{ "debugger", .t_reserved },
        .{ "decltype", .t_reserved },
        .{ "delete", .t_reserved },
        .{ "demote", .t_reserved },
        .{ "demote_to_helper", .t_reserved },
        .{ "do", .t_reserved },
        .{ "dynamic_cast", .t_reserved },
        .{ "enum", .t_reserved },
        .{ "explicit", .t_reserved },
        .{ "export", .t_reserved },
        .{ "extends", .t_reserved },
        .{ "extern", .t_reserved },
        .{ "external", .t_reserved },
        .{ "fallthrough", .t_reserved },
        .{ "filter", .t_reserved },
        .{ "final", .t_reserved },
        .{ "finally", .t_reserved },
        .{ "friend", .t_reserved },
        .{ "from", .t_reserved },
        .{ "fxgroup", .t_reserved },
        .{ "get", .t_reserved },
        .{ "goto", .t_reserved },
        .{ "groupshared", .t_reserved },
        .{ "highp", .t_reserved },
        .{ "impl", .t_reserved },
        .{ "implements", .t_reserved },
        .{ "import", .t_reserved },
        .{ "inline", .t_reserved },
        .{ "instanceof", .t_reserved },
        .{ "interface", .t_reserved },
        .{ "layout", .t_reserved },
        .{ "lowp", .t_reserved },
        .{ "macro", .t_reserved },
        .{ "macro_rules", .t_reserved },
        .{ "match", .t_reserved },
        .{ "mediump", .t_reserved },
        .{ "meta", .t_reserved },
        .{ "mod", .t_reserved },
        .{ "module", .t_reserved },
        .{ "move", .t_reserved },
        .{ "mut", .t_reserved },
        .{ "mutable", .t_reserved },
        .{ "namespace", .t_reserved },
        .{ "new", .t_reserved },
        .{ "nil", .t_reserved },
        .{ "noexcept", .t_reserved },
        .{ "noinline", .t_reserved },
        .{ "nointerpolation", .t_reserved },
        .{ "noperspective", .t_reserved },
        .{ "null", .t_reserved },
        .{ "nullptr", .t_reserved },
        .{ "of", .t_reserved },
        .{ "operator", .t_reserved },
        .{ "package", .t_reserved },
        .{ "packoffset", .t_reserved },
        .{ "partition", .t_reserved },
        .{ "pass", .t_reserved },
        .{ "patch", .t_reserved },
        .{ "pixelfragment", .t_reserved },
        .{ "precise", .t_reserved },
        .{ "precision", .t_reserved },
        .{ "premerge", .t_reserved },
        .{ "priv", .t_reserved },
        .{ "protected", .t_reserved },
        .{ "pub", .t_reserved },
        .{ "public", .t_reserved },
        .{ "readonly", .t_reserved },
        .{ "ref", .t_reserved },
        .{ "regardless", .t_reserved },
        .{ "register", .t_reserved },
        .{ "reinterpret_cast", .t_reserved },
        .{ "require", .t_reserved },
        .{ "resource", .t_reserved },
        .{ "restrict", .t_reserved },
        .{ "self", .t_reserved },
        .{ "set", .t_reserved },
        .{ "shared", .t_reserved },
        .{ "sizeof", .t_reserved },
        .{ "smooth", .t_reserved },
        .{ "snorm", .t_reserved },
        .{ "static", .t_reserved },
        .{ "static_assert", .t_reserved },
        .{ "static_cast", .t_reserved },
        .{ "std", .t_reserved },
        .{ "subroutine", .t_reserved },
        .{ "super", .t_reserved },
        .{ "target", .t_reserved },
        .{ "template", .t_reserved },
        .{ "this", .t_reserved },
        .{ "thread_local", .t_reserved },
        .{ "throw", .t_reserved },
        .{ "trait", .t_reserved },
        .{ "try", .t_reserved },
        .{ "type", .t_reserved },
        .{ "typedef", .t_reserved },
        .{ "typeid", .t_reserved },
        .{ "typename", .t_reserved },
        .{ "typeof", .t_reserved },
        .{ "union", .t_reserved },
        .{ "unless", .t_reserved },
        .{ "unorm", .t_reserved },
        .{ "unsafe", .t_reserved },
        .{ "unsized", .t_reserved },
        .{ "use", .t_reserved },
        .{ "using", .t_reserved },
        .{ "varying", .t_reserved },
        .{ "virtual", .t_reserved },
        .{ "volatile", .t_reserved },
        .{ "wgsl", .t_reserved },
        .{ "where", .t_reserved },
        .{ "with", .t_reserved },
        .{ "writeonly", .t_reserved },
        .{ "yield", .t_reserved },
    });
};

source: []const u8,
codepoint: i32,
index: usize,
start: usize,
token: Token,
has_newline_before: bool,

discovered_starts: [:0]u32,
discovered_starts_idx: u32 = 0,
discovered_ends: [:0]u32,
discovered_ends_idx: u32 = 0,

pub fn init(allocator: std.mem.Allocator, source: []const u8) std.mem.Allocator.Error!Lexer {
    var discovered = try discovery.discover(allocator, source);
    return .{
        .source = source,
        .codepoint = source[0],
        .index = 0,
        .start = 0,
        .token = .t_eof,
        .has_newline_before = false,
        .discovered_starts = discovered.starts,
        .discovered_ends = discovered.ends,
    };
}

pub fn deinit(lex: *Lexer) void {
    lex.discovered_starts.deinit(lex.allocator);
    lex.discovered_ends.deinit(lex.allocator);
}

pub fn readSpan(lex: *const Lexer, s: Span) []const u8 {
    return lex.source[s.start..s.end];
}

fn step(lex: *Lexer) void {
    if (lex.codepoint == -1) {
        return;
    }

    std.debug.assert(lex.codepoint >= 0);

    lex.index += std.unicode.utf8CodepointSequenceLength(@as(u21, @intCast(lex.codepoint))) catch unreachable;
    lex.codepoint = if (lex.index >= lex.source.len) -1 else std.unicode.utf8Decode(lex.source[lex.index..][0 .. std.unicode.utf8ByteSequenceLength(lex.source[lex.index]) catch unreachable]) catch unreachable;
}

pub fn span(lex: *const Lexer) Span {
    return Span{
        .start = @as(u32, @truncate(lex.start)),
        .end = @as(u32, @truncate(lex.index)),
    };
}

pub fn next(lex: *Lexer) void {
    lex.has_newline_before = false;
    main: while (true) {
        lex.start = lex.index;

        switch (lex.codepoint) {
            '_' => {
                lex.step();
                if (std.ascii.isAlphanumeric(@intCast(lex.codepoint))) {
                    lex.step();
                    lex.token = .t_ident;
                    lex.continueIdentFast();
                } else {
                    lex.token = .t_under;
                }
            },
            'a'...'z', 'A'...'Z' => {
                lex.token = .t_ident;
                lex.step();
                lex.continueIdentFast();
            },
            '0' => {
                lex.token = .t_number;
                lex.step();

                switch (lex.codepoint) {
                    'x', 'X' => {
                        lex.step();
                        lex.continueNumber(NumberState{ .seen_hex = true });
                    },
                    'i', 'u', 'f', 'h' => lex.step(),
                    else => lex.continueNumber(NumberState{}),
                }
            },
            '1'...'9' => {
                lex.token = .t_number;
                lex.step();
                lex.continueNumber(NumberState{ .seen_dec = false, .seen_exp = false });
            },
            // https://www.w3.org/TR/WGSL/#blankspace-and-line-breaks
            '\u{0020}', '\u{0009}' => {
                lex.step();
                continue :main;
            },
            '\u{000A}', '\u{000B}', '\u{000C}', '\u{000D}', '\u{0085}', '\u{200E}', '\u{200F}', '\u{2028}', '\u{2029}' => {
                lex.has_newline_before = true;
                lex.step();
                continue :main;
            },
            // https://www.w3.org/TR/WGSL/#comments
            '/' => {
                lex.step();

                lex.token = .t_comment;

                switch (lex.codepoint) {
                    '/' => {
                        lex.step();
                        lex.continueLineComment();
                        continue :main;
                    },
                    '*' => {
                        lex.step();
                        lex.continueBlockComment();
                        continue :main;
                    },
                    '=' => {
                        lex.step();
                        lex.token = .t_div_assign;
                    },
                    else => lex.token = .t_div,
                }
            },
            // https://www.w3.org/TR/WGSL/#syntactic-tokens
            '&' => {
                lex.step();
                switch (lex.codepoint) {
                    '=' => {
                        lex.step();
                        lex.token = .t_bit_and_assign;
                    },
                    '&' => {
                        lex.step();
                        lex.token = .t_and;
                    },
                    else => lex.token = .t_bit_and,
                }
            },
            '-' => {
                lex.step();
                switch (lex.codepoint) {
                    '>' => {
                        lex.step();
                        lex.token = .t_thin_arrow;
                    },
                    '-' => {
                        lex.step();
                        lex.token = .t_dec;
                    },
                    '=' => {
                        lex.step();
                        lex.token = .t_sub_assign;
                    },
                    else => lex.token = .t_sub,
                }
            },
            '@' => {
                lex.step();
                lex.token = .t_at;
            },
            '!' => {
                lex.step();
                lex.token = if (lex.codepoint == '=') blk: {
                    lex.step();
                    break :blk .t_not_equal;
                } else .t_not;
            },
            '[' => {
                lex.step();
                lex.token = .t_lbrack;
            },
            ']' => {
                lex.step();
                lex.token = .t_rbrack;
            },
            '{' => {
                lex.step();
                lex.token = .t_lbrace;
            },
            '}' => {
                lex.step();
                lex.token = .t_rbrace;
            },
            ':' => {
                lex.step();
                lex.token = .t_colon;
            },
            ',' => {
                lex.step();
                lex.token = .t_comma;
            },
            '=' => {
                lex.step();
                lex.token = if (lex.codepoint == '=') blk: {
                    lex.step();
                    break :blk .t_equality;
                } else .t_assign;
            },
            '>' => {
                if (lex.discovered_ends[lex.discovered_ends_idx] == lex.index) {
                    lex.discovered_ends_idx += 1;
                    lex.step();
                    lex.token = .t_template_end;
                    break;
                }

                lex.step();
                switch (lex.codepoint) {
                    '=' => {
                        lex.step();
                        lex.token = .t_greater_than_equal;
                    },
                    '>' => {
                        lex.step();
                        lex.token = if (lex.codepoint == '=') blk: {
                            lex.step();
                            break :blk .t_bit_right_assign;
                        } else .t_bit_right;
                    },
                    else => {
                        lex.token = .t_greater_than;
                    },
                }
            },
            '<' => {
                if (lex.discovered_starts[lex.discovered_starts_idx] == lex.index) {
                    lex.discovered_starts_idx += 1;
                    lex.step();
                    lex.token = .t_template_start;
                    break;
                }

                lex.step();
                switch (lex.codepoint) {
                    '=' => {
                        lex.step();
                        lex.token = .t_less_than_equal;
                    },
                    '<' => {
                        lex.step();
                        lex.token = if (lex.codepoint == '=') blk: {
                            lex.step();
                            break :blk .t_bit_left_assign;
                        } else .t_bit_left;
                    },
                    else => {
                        lex.token = .t_less_than;
                    },
                }
            },
            '%' => {
                lex.step();
                lex.token = if (lex.codepoint == '=') blk: {
                    lex.step();
                    break :blk .t_mod_assign;
                } else .t_mod;
            },
            '.' => {
                lex.step();

                switch (lex.codepoint) {
                    '0'...'9' => {
                        lex.token = .t_number;
                        lex.step();
                        lex.continueNumber(NumberState{ .seen_dec = true, .seen_exp = false });
                    },
                    else => lex.token = .t_dot,
                }
            },
            '+' => {
                lex.step();
                switch (lex.codepoint) {
                    '+' => {
                        lex.step();
                        lex.token = .t_inc;
                    },
                    '=' => {
                        lex.step();
                        lex.token = .t_add_assign;
                    },
                    else => lex.token = .t_add,
                }
            },
            '|' => {
                lex.step();
                switch (lex.codepoint) {
                    '|' => {
                        lex.step();
                        lex.token = .t_or;
                    },
                    '=' => {
                        lex.step();
                        lex.token = .t_bit_or_assign;
                    },
                    else => lex.token = .t_bit_or,
                }
            },
            '(' => {
                lex.step();
                lex.token = .t_lparen;
            },
            ')' => {
                lex.step();
                lex.token = .t_rparen;
            },
            ';' => {
                lex.step();
                lex.token = .t_semi;
            },
            '*' => {
                lex.step();
                lex.token = if (lex.codepoint == '=') blk: {
                    lex.step();
                    break :blk .t_mul_assign;
                } else .t_mul;
            },
            '~' => {
                lex.step();
                lex.token = .t_bit_not;
            },
            '^' => {
                lex.step();
                lex.token = if (lex.codepoint == '=') blk: {
                    lex.step();
                    break :blk .t_bit_xor_assign;
                } else .t_bit_xor;
            },
            -1 => lex.token = .t_eof,
            else => {
                lex.step();
                lex.token = .t_unknown;
            },
        }

        break :main;
    }
}

const NumberState = struct {
    seen_dec: bool = false,
    seen_exp: bool = false,
    seen_hex: bool = false,
};

fn continueNumber(lex: *Lexer, newState: NumberState) void {
    var state = newState;
    while (true) {
        switch (lex.codepoint) {
            '0'...'9' => lex.step(),
            '.' => {
                if (state.seen_dec or state.seen_exp) {
                    break;
                }
                lex.step();
                state.seen_dec = true;
            },
            'e', 'E' => {
                if (state.seen_hex) {
                    lex.step();
                    continue;
                }

                if (state.seen_exp) {
                    break;
                }

                lex.step();
                state.seen_exp = true;
                switch (lex.codepoint) {
                    '+', '-' => lex.step(),
                    '0'...'9' => lex.step(),
                    else => break,
                }
            },
            'p', 'P' => {
                if (!state.seen_hex or state.seen_exp) {
                    break;
                }

                lex.step();
                state.seen_exp = true;
                switch (lex.codepoint) {
                    '+', '-' => lex.step(),
                    '0'...'9' => lex.step(),
                    else => break,
                }
            },
            'i', 'u', 'f', 'h' => {
                lex.step();
                if (!state.seen_hex) break;
            },
            'a', 'b', 'c', 'A', 'B', 'C' => {
                if (!state.seen_hex) {
                    break;
                }
                lex.step();
            },
            else => break,
        }
    }
}

fn continueIdentFast(lex: *Lexer) void {
    while (true) {
        switch (lex.codepoint) {
            'a'...'z', 'A'...'Z', '0'...'9', '_' => lex.step(),
            else => {
                if (lex.codepoint <= 0x80) {
                    lex.token = interesting
                        .get(lex.source[lex.start..lex.index]) orelse .t_ident;
                    break;
                }

                return lex.continueIdentSlow();
            },
        }
    }
}

fn continueIdentSlow(lex: *Lexer) void {
    _ = lex;
    // while (true) {
    // if let c) = lex.codepoint && c.is
    // }
}

// https://www.w3.org/TR/WGSL/#line-ending-comment
fn continueLineComment(lex: *Lexer) void {
    while (true) {
        switch (lex.codepoint) {
            '\u{000A}', '\u{000B}', '\u{000C}', '\u{000D}', '\u{0085}', '\u{200E}', '\u{200F}', '\u{2028}', '\u{2029}' => break,
            else => lex.step(),
        }
    }
}

// https://www.w3.org/TR/WGSL/#block-comment
fn continueBlockComment(lex: *Lexer) void {
    while (true) {
        switch (lex.codepoint) {
            '/' => {
                lex.step();
                if (lex.codepoint == '*') {
                    lex.step();
                    lex.continueBlockComment();
                }
            },
            '*' => {
                lex.step();
                if (lex.codepoint == '/') {
                    lex.step();
                    return;
                }
            },
            -1 => @panic("todo"),
            else => lex.step(),
        }
    }
}
