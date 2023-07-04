const std = @import("std");
const Lexer = @import("Lexer.zig");
const ast = @import("ast.zig");
const Parser = @import("Parser.zig");
const Analyzer = @import("Analyzer.zig");
const Reporter = @import("Reporter.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var file = try std.fs.cwd().readFileAlloc(arena.allocator(), "source.wgsl", 4096);

    var reporter = Reporter.init(arena.allocator());
    _ = reporter.pushSource(file);

    var p = try Parser.init(arena.allocator(), file, &reporter);

    var scope = p.parseGlobalScope() catch &.{};

    var inspector = Analyzer{ .allocator = p.arena, .source = p.lex.source, .reporter = &reporter };
    try inspector.loadGlobalTypes();
    var env = Analyzer.Env{};

    try inspector.loadTypes(&env, scope);
    for (scope) |stmt| {
        try inspector.check(&env, stmt);
    }

    try reporter.dump(std.io.getStdErr().writer());

    var env_iter = env.bindings.iterator();
    while (env_iter.next()) |entry| {
        std.debug.print("'{s}': {}\n", .{ entry.key_ptr.*, entry.value_ptr });
    }
}
