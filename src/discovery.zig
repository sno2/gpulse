// Mostly follows the specification: https://www.w3.org/TR/WGSL/#template-list-discovery
//
// The only difference is that the discovery algorithm only recognizes
// starting templates (`<`) after an identifier. However, we lazily validate
// this information in the parser to improve error messages.

// TODO: Check if reimplementing this logic to run lazily when we encounter `<`
//       in the lexer is more efficient than iterating the entire file.

const std = @import("std");

pub const TemplateList = struct {
    start: u32,
    end: u32,
};

pub const Pending = struct {
    depth: u32,
    index: u32,
};

const TemplateListData = struct {
    starts: [:0]u32,
    ends: [:0]u32,
};

pub fn discover(allocator: std.mem.Allocator, source: []const u8) std.mem.Allocator.Error!TemplateListData {
    var index: u32 = 0;
    var depth: u32 = 0;

    var discovered = try std.ArrayList(TemplateList).initCapacity(allocator, 16);
    defer discovered.deinit();

    var pending = try std.ArrayList(Pending).initCapacity(allocator, 16);
    defer pending.deinit();

    while (index < source.len) {
        switch (source[index]) {
            '<' => {
                try pending.append(.{ .index = index, .depth = depth });
                index += 1;

                if (index < source.len and (index == '<' or index == '=')) {
                    _ = pending.pop();
                    index += 1;
                }
            },
            '>' => blk: {
                var node = pending.getLastOrNull();

                if (node != null and node.?.depth == depth) {
                    try discovered.append(.{ .start = node.?.index, .end = index });
                    _ = pending.pop();
                    index += 1;
                    break :blk;
                } else {
                    index += 1;
                    if (index < source.len and source[index] == '=') {
                        index += 1;
                    }
                }
            },
            '(', '[' => {
                depth += 1;
                index += 1;
            },
            ')', ']' => {
                pruneUnusedPending(&pending, depth);
                depth -|= 1;
                index += 1;
            },
            '!' => {
                index += 1;
                if (index < source.len and source[index] == '=') {
                    index += 1;
                }
            },
            '=' => {
                index += 1;
                if (index < source.len and source[index] == '=') {
                    index += 1;
                    continue;
                }
                depth = 0;
                pending.clearRetainingCapacity();
                index += 1;
            },
            ';', '{', ':' => {
                depth = 0;
                pending.clearRetainingCapacity();
                index += 1;
            },
            '&' => {
                index += 1;
                if (index < source.len and source[index] == '&') {
                    pruneUnusedPending(&pending, depth);
                    index += 1;
                }
            },
            '|' => {
                index += 1;
                if (index < source.len and source[index] == '|') {
                    pruneUnusedPending(&pending, depth);
                    index += 1;
                }
            },
            // Skip whitespace
            '/' => blk: {
                index += 1;

                if (index >= source.len) break :blk;

                if (source[index] == '*') {
                    var open: usize = 0;
                    index += 1;
                    while (index < source.len) {
                        switch (source[index]) {
                            '/' => {
                                index += 1;
                                if (index < source.len and source[index] == '*') {
                                    index += 1;
                                    open += 1;
                                }
                            },
                            '*' => {
                                index += 1;
                                if (index < source.len and source[index] == '/') {
                                    if (open == 0) {
                                        break;
                                    }
                                    open -= 1;
                                }
                            },
                            else => index += 1,
                        }
                    }
                } else if (source[index] == '/') {
                    index += 1;

                    if (index >= source.len) break :blk;

                    var iterator = std.unicode.Utf8Iterator{ .bytes = source, .i = index };

                    while (iterator.nextCodepoint()) |cp| {
                        switch (cp) {
                            '\u{000A}', '\u{000B}', '\u{000C}', '\u{000D}', '\u{0085}', '\u{200E}', '\u{200F}', '\u{2028}', '\u{2029}' => break,
                            else => {},
                        }
                    }

                    index = @truncate(iterator.i);
                }
            },
            else => index += 1,
        }
    }

    var starts = try allocator.allocSentinel(u32, discovered.items.len, 0);
    var ends = try allocator.allocSentinel(u32, discovered.items.len, 0);

    for (discovered.items, 0..) |item, i| {
        starts[i] = item.start;
        ends[i] = item.end;
    }

    std.mem.sort(u32, starts, {}, struct {
        fn compare(_: void, lhs: u32, rhs: u32) bool {
            return lhs < rhs;
        }
    }.compare);

    std.mem.sort(u32, ends, {}, struct {
        fn compare(_: void, lhs: u32, rhs: u32) bool {
            return lhs < rhs;
        }
    }.compare);

    return .{
        .starts = starts,
        .ends = ends,
    };
}

inline fn pruneUnusedPending(list: *std.ArrayList(Pending), depth: u32) void {
    var len = list.items.len;

    while (len > 1) {
        if (list.items[len - 1].depth <= depth) break;
        len -= 1;
    }

    list.items.len = len;
}
