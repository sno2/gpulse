const std = @import("std");
const Server = @This();
const types = @import("types.zig");
const Header = @import("Header.zig");

pending_messages: std.ArrayListUnmanaged([]const u8) = .{},

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    var allocator = arena.allocator();

    var server = Server{};
    defer server.pending_messages.deinit(allocator);

    var stdin = std.io.getStdIn().reader();
    var stdout = std.io.getStdOut().writer();

    var buffered_reader = std.io.bufferedReader(stdin);
    var buffered_writer = std.io.bufferedWriter(stdout);

    var reader = buffered_reader.reader();
    var writer = buffered_writer.writer();

    // A stack-based fallback for parsing headers.
    var fallback = std.heap.stackFallback(512, allocator);
    var fallback_allocator = fallback.get();

    // Main loop
    while (true) {
        // Send all pending messages to the client.
        for (server.pending_messages.items) |message| {
            const header = Header{ .content_length = message.len };
            try header.write(true, writer);
            try writer.writeAll(message);
        }

        // Flush messages to stdout.
        try buffered_writer.flush();

        // Read message header from client.
        const header = try Header.parse(fallback_allocator, true, reader);

        // Read JSON message contents.
        const json_message = try allocator.alloc(u8, header.content_length);
        try reader.readNoEof(json_message);

        std.debug.print("message: {s}", .{json_message});

        // Clear pending messages and maybe reset arena.
        server.pending_messages.clearRetainingCapacity();
        _ = arena.reset(.{ .retain_with_limit = 128 * 1024 });
    }
}
