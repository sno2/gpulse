const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("Parser.zig");
const Reporter = @import("Reporter.zig");

pub fn main() !void {
    var testsFolder = try std.fs.cwd().openIterableDir("tests", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var iterator = testsFolder.iterate();

    var ran: usize = 0;
    var failed: usize = 0;

    while (try iterator.next()) |entry| {
        if (entry.kind != .file or std.mem.endsWith(u8, entry.name, ".snap") or std.mem.endsWith(u8, entry.name, ".stat")) continue;
        ran += 1;

        defer _ = arena.reset(.retain_capacity);

        var test0 = try testsFolder.dir.readFileAlloc(arena.allocator(), entry.name, 4096 * 4);

        var reporter = Reporter.init(arena.allocator());
        _ = reporter.pushSource(test0);

        var p = try Parser.init(arena.allocator(), test0, &reporter);

        var debug = std.ArrayList(u8).init(arena.allocator());

        var scope = p.parseGlobalScope() catch &.{};

        if (reporter.diagnostics.items.len != 0) {
            failed += 1;
            try reporter.dump(debug.writer());
        } else {
            for (scope) |node| {
                try std.fmt.formatType(node, "", .{}, debug.writer(), 100000);
                try debug.append(' ');
            }
        }

        var snap = try std.fmt.allocPrint(arena.allocator(), "{s}.snap", .{entry.name});
        try testsFolder.dir.writeFile(snap, debug.items);
    }

    var stat_message = try std.fmt.allocPrint(arena.allocator(), "{} passed\n{} failed\n", .{ ran - failed, failed });
    try testsFolder.dir.writeFile("_manifest.stat", stat_message);
    var stdout = std.io.getStdOut();
    try stdout.writeAll(stat_message);
}
