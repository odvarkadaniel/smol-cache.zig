const std = @import("std");
const dll = @import("dll.zig");

const Allocator = std.mem.Allocator;

pub fn Entry(comptime T: type) type {
    return struct {
        const List = dll.List(*Self);

        allocator: Allocator,
        key: []const u8,
        value: T,
        node: ?*List.Node,
        expires: i64,
        // What about size of the item to track size < max_size?

        const Self = @This();

        pub fn init(allocator: Allocator, key: []const u8, value: T, expires: i64) Self {
            return .{
                .allocator = allocator,
                .key = key,
                .value = value,
                .node = null,
                .expires = expires,
            };
        }

        pub fn expired(self: *Self) bool {
            return (self.expires - std.time.timestamp()) < 0;
        }

        pub fn release(self: *Self) void {
            const allocator = self.allocator;
            const node = self.node;

            allocator.free(self.key);
            allocator.destroy(node);
            allocator.destroy(self);
        }
    };
}
