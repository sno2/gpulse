const std = @import("std");
const Header = @This();

content_length: usize,
content_type: ?[]u8 = null,

pub fn deinit(self: @This(), allocator: std.mem.Allocator) void {
    if (self.content_type) |x| {
        allocator.free(x);
    }
}

pub const E = error{
    InvalidHeader,
    InvalidContentLength,
    InvalidContentType,
    InvalidHeaderSeparator,
};

const content_start = std.mem.readIntNative(u64, &"Content-"[0..8].*);
const length_start = std.mem.readIntNative(u64, &"Length: "[0..8].*);
const type_start = std.mem.readIntNative(u64, &"Type: \"\x00".*);

// Maps ASCII charcters to state results.
// States:
//   Invalid = 0
//   Regular = 1
//   Quoted  = 2
const field_states = [256][3]u8{ .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 1 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 1, 1 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 0, 0 }, .{ 0, 1, 1 }, .{ 0, 1, 0 }, .{ 0, 0, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 2, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 1, 0 }, .{ 0, 0, 0 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 }, .{ 0, 1, 1 } };

// Caller owns returned memory.
pub fn parse(allocator: std.mem.Allocator, comptime require_carriage_return: bool, reader: anytype) !Header {
    var content_length: ?usize = null;
    var content_type: ?[]u8 = null;

    while (true) {
        var offset: usize = 0;
        var bytes = try reader.readUntilDelimiterAlloc(allocator, '\n', 0x100);

        if (bytes.len < 16) {
            if (offset + 1 == bytes.len and bytes[offset] == '\r') {
                break;
            } else if (!require_carriage_return and bytes.len == 0) {
                break;
            }

            return error.InvalidHeader;
        }

        const first8 = std.mem.readIntNative(u64, &(bytes[offset..][0..8].*));

        if (first8 != content_start) {
            return error.InvalidHeader;
        }

        const second8 = std.mem.readIntNative(u64, &(bytes[offset..][8..16].*));

        if (second8 == length_start) {
            // Content-Length = 1*DIGIT

            offset += 16;
            content_length = 0;

            while (offset < bytes.len) : (offset += 1) {
                var digit = bytes[offset];
                if (std.ascii.isDigit(digit)) {
                    content_length.? *|= 10;
                    content_length.? +|= digit - '0';
                } else {
                    break;
                }
            }
        } else if (second8 << 8 >> 8 == type_start) {
            offset += 15;

            const start = offset;
            var state: u8 = 1;

            while (offset < bytes.len and state != 0) : (offset += 1) {
                state = field_states[bytes[offset]][state];
            }

            content_type = bytes[start .. offset - 1];
        } else {
            return error.InvalidHeaderName;
        }

        if (offset + 1 == bytes.len and bytes[offset] == '\r' or !require_carriage_return and bytes.len == 0) {} else {
            return error.InvalidHeader;
        }
    }

    return Header{
        .content_length = content_length orelse return error.InvalidContentLength,
        .content_type = content_type,
    };
}

pub fn write(header: Header, comptime include_carriage_return: bool, writer: anytype) @TypeOf(writer).Error!void {
    const separator: []const u8 = if (include_carriage_return) "\r\n" else "\n";
    try writer.print("Content-Length: {}" ++ separator, .{header.content_length});
    if (header.content_type) |content_type| {
        try writer.print("Content-Type: {s}" ++ separator, .{content_type});
    }
    try writer.writeAll(separator);
}
