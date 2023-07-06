const std = @import("std");
const ast = @import("ast.zig");
const Span = ast.Span;
const Token = @import("Lexer.zig").Token;
const Reporter = @This();
const Type = @import("Analyzer.zig").Type;

pub const Diagnostic = struct {
    source_id: ?u32 = null,
    span: Span,
    kind: union(enum) {
        // Parser errors
        expected: struct {
            expected: Token,
            got: Token,
        },
        expected_expression: Token,
        expected_statement: Token,
        invalid_severity_name,
        invalid_type_alias,
        unknown_attribute_name: []const u8,
        expected_switch_clause: Token,
        expected_ident_template,
        invalid_expr_statement,
        invalid_override_statement,

        // Analyzer errors
        not_assignable: struct {
            expected: Type,
            got: Type,
        },
        unknown_type: []const u8,
        unknown_template: []const u8,
        not_callable_type: Type,
        expected_n_args: struct {
            expected: u32,
            got: u32,
        },
        unknown_name: []const u8,
        expected_n_template_args: struct {
            expected: u32,
            expected_max: ?u32 = null,
            got: u32,
        },
    },

    pub fn format(diag: Diagnostic, comptime _: []const u8, _: std.fmt.FormatOptions, writer: anytype) !void {
        switch (diag.kind) {
            // Parser errors
            .expected => |data| {
                try writer.print("Expected {}, found {}.", .{ data.expected, data.got });
            },
            .expected_expression => |x| try writer.print("Expected expression, found {}.", .{x}),
            .expected_statement => |x| try writer.print("Expected statement, found {}.", .{x}),
            .invalid_severity_name => try writer.writeAll("Invalid severity name."),
            .invalid_type_alias => try writer.writeAll("Invalid type alias."),
            .unknown_attribute_name => |x| try writer.print("Unknown attribute name: '{s}'.", .{x}),
            .expected_switch_clause => |x| try writer.print("Expected a switch clause, found {}.", .{x}),
            .expected_ident_template => try writer.print("Expected an identifier for template specialization.", .{}),
            .invalid_expr_statement => try writer.print("Cannot use expression as a statement. Consider using '_ = '.", .{}),
            .invalid_override_statement => try writer.writeAll("Override declarations are only allowed in the global scope."),

            // Analyzer errors
            .not_assignable => |x| try writer.print("Expected '{}', found '{}'.", .{ x.expected, x.got }),
            .unknown_type => |x| try writer.print("Type '{s}' not found in this scope.", .{x}),
            .unknown_template => |x| try writer.print("Template '{s}' not found in this scope.", .{x}),
            .not_callable_type => |x| try writer.print("Type '{}' is not a callable type.", .{x}),
            .expected_n_args => |x| try writer.print("Expected {} argument{s}, got {}.", .{ x.expected, if (x.expected != 1) "s" else "", x.got }),
            .unknown_name => |x| try writer.print("'{s}' not found in this scope.", .{x}),
            .expected_n_template_args => |x| {
                if (x.expected_max) |max| {
                    try writer.print("Expected {} to {} template arguments, got {}.", .{ x.expected, max, x.got });
                } else {
                    try writer.print("Expected {} template argument{s}, got {}.", .{ x.expected, if (x.expected != 1) "s" else "", x.got });
                }
            },
        }
    }
};

allocator: std.mem.Allocator,
diagnostics: std.ArrayListUnmanaged(Diagnostic) = .{},
sources: std.ArrayListUnmanaged([]const u8) = .{},
cur_source: u32 = 0,

pub fn init(allocator: std.mem.Allocator) Reporter {
    return Reporter{ .allocator = allocator };
}

pub fn add(reporter: *Reporter, diagnostic: Diagnostic) void {
    @setCold(true);
    var data = diagnostic;
    if (data.source_id == null) {
        data.source_id = reporter.cur_source;
    }
    reporter.diagnostics.append(reporter.allocator, data) catch unreachable;
}

pub fn pushSource(reporter: *Reporter, source: []const u8) u32 {
    var id: u32 = @truncate(reporter.sources.items.len);
    reporter.sources.append(reporter.allocator, source) catch unreachable;
    reporter.cur_source = id;
    return id;
}

fn findLine(source: []const u8, span: ast.Span) struct { []const u8, usize } {
    var start = @min(source.len - 1, span.start);
    var end = span.end;

    while (start > 0) : (start -= 1) {
        if (source[start] == '\n') {
            start += 1;
            break;
        }
    }

    while (end < source.len) : (end += 1) {
        if (source[end] == '\n') break;
    }

    return .{ source[start..end], span.start - start };
}

const spaces: [128]u8 = .{' '} ** 128;
const tildes: [128]u8 = .{'~'} ** 128;

pub fn dump(reporter: *Reporter, writer: anytype) !void {
    if (reporter.diagnostics.items.len != 0) {
        for (reporter.diagnostics.items) |diag| {
            try writer.print("error: {}\n\n", .{diag});
            var line = findLine(reporter.sources.items[diag.source_id.?], diag.span);
            try writer.print("{s}\n", .{line.@"0"});
            try writer.print("{s}{s}\n", .{ spaces[0..line.@"1"], tildes[0 .. diag.span.end - diag.span.start] });
        }
        reporter.diagnostics.items.len = 0;
    }
}
