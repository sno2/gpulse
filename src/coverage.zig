const std = @import("std");
const ast = @import("ast.zig");
const Parser = @import("Parser.zig");
const Reporter = @import("Reporter.zig");

const TestStat = struct {
    total: usize,
    failed: usize,

    pub fn passed(self: TestStat) usize {
        return self.total - self.failed;
    }
};

fn testSuite(arena: *std.heap.ArenaAllocator, testsFolder: std.fs.Dir, name: []const u8) !TestStat {
    var iter = try testsFolder.openIterableDir(name, .{});
    var walker = try iter.walk(std.heap.page_allocator);
    defer walker.deinit();

    var total: usize = 0;
    var failed: usize = 0;

    while (try walker.next()) |entry| {
        if (entry.kind != .file or std.mem.endsWith(u8, entry.basename, ".snap")) continue;
        total += 1;

        defer _ = arena.reset(.retain_capacity);

        var file = try iter.dir.readFileAlloc(arena.allocator(), entry.basename, 262144);

        var reporter = Reporter.init(arena.allocator());
        _ = reporter.pushSource(file);

        var p = try Parser.init(arena.allocator(), file, &reporter);

        var debug = std.ArrayList(u8).init(arena.allocator());

        var scope = p.parseGlobalScope() catch &.{};

        if (reporter.diagnostics.items.len != 0) {
            failed += 1;
            try reporter.dump(debug.writer());
        } else {
            for (scope) |node| {
                try std.fmt.formatType(node, "", .{}, debug.writer(), 100000);
                try debug.append('\n');
            }
        }

        var snap = try std.fmt.allocPrint(arena.allocator(), "{s}.snap", .{entry.basename});
        try iter.dir.writeFile(snap, debug.items);
    }

    return .{ .total = total, .failed = failed };
}

pub fn main() !void {
    var testsFolder = try std.fs.cwd().openDir("tests", .{});
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    // Load arena with the maximum memory required.
    _ = try arena.allocator().alloc(u8, 607337);
    _ = arena.reset(.retain_capacity);

    var specExamples = try testSuite(&arena, testsFolder, "spec-examples");
    var tourExamples = try testSuite(&arena, testsFolder, "tour-of-wgsl");
    var custom = try testSuite(&arena, testsFolder, "custom");

    var stat_message = try std.fmt.allocPrint(arena.allocator(),
        \\WGSL Specification Examples ({})
        \\✅ {} passed
        \\❌ {} failed
        \\
        \\Tour of WGSL Examples ({})
        \\✅ {} passed
        \\❌ {} failed
        \\
        \\Custom ({})
        \\✅ {} passed
        \\❌ {} failed
    ++ "\n", .{
        specExamples.total,
        specExamples.passed(),
        specExamples.failed,
        tourExamples.total,
        tourExamples.passed(),
        tourExamples.failed,
        custom.total,
        custom.passed(),
        custom.failed,
    });
    try testsFolder.writeFile("_manifest.stat", stat_message);
    var stdout = std.io.getStdOut();
    try stdout.writeAll(stat_message);
}
