const std = @import("std");
const dll = @import("dll.zig");

pub fn Entry(comptime T: type) type {
    return struct {
        const List = dll.List(T);

        key: []const u8,
        value: T,
        node: ?*List.Node,
        expires: i64,
        // What about size of the item to track size < max_size?

        const Self = @This();

        pub fn init(key: []const u8, value: T, expires: i64) Self {
            return .{
                .key = key,
                .value = value,
                .node = null,
                .expires = expires,
            };
        }

        pub fn expired(self: Self) bool {
            return (self.expires - std.time.timestamp()) < 0;
        }
    };
}
