const std = @import("std");
const Parser = @import("Parser.zig");
const Reporter = @import("Reporter.zig");

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    var seed_bytes: [8]u8 = undefined;
    try std.os.getrandom(&seed_bytes);

    var seed = std.mem.readIntNative(u64, &seed_bytes);

    var prng = std.rand.Xoshiro256.init(seed);

    while (true) {
        defer _ = arena.reset(.retain_capacity);

        var len = prng.random().float(f32);
        var bytes = try arena.allocator().alloc(u8, @intFromFloat(@trunc(len * 500)));

        prng.fill(bytes);

        var reporter = Reporter.init(arena.allocator());
        _ = reporter.pushSource(bytes);
        var p = try Parser.init(arena.allocator(), bytes, &reporter);
        var scope = p.parseGlobalScope() catch &.{};
        _ = scope;

        if (p.reporter.diagnostics.items.len != 0) {
            var stdout_writer = std.io.getStdOut().writer();
            try stdout_writer.print("input:\n{s}", .{bytes});
            try reporter.dump(stdout_writer);
        }
    }
}
