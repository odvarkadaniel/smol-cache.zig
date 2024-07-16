const std = @import("std");
const dll = @import("dll.zig");
const entry = @import("entry.zig");

const Allocator = std.mem.Allocator;

pub const Config = struct {
    maxSize: u32,
    // Might add more configuration in the future.
};

pub fn Cache(comptime T: type) type {
    return struct {
        allocator: Allocator,
        size: u32,
        maxSize: u32,

        list: List,
        memory: std.StringHashMap(*Entry),

        const Self = @This();
        const Entry = entry.Entry(T);
        const List = dll.List(*Entry);

        pub fn init(allocator: Allocator, conf: Config) !Self {
            return .{
                .allocator = allocator,
                .size = 0,
                .maxSize = conf.maxSize,
                .list = List.init(),
                .memory = std.StringHashMap(*Entry).init(allocator),
            };
        }

        pub fn deinit(self: *Self) void {
            var it = self.memory.iterator();
            while (it.next()) |kv| {
                const e = kv.value_ptr.*;
                self.list.remove(e.node.?);
                e.release();
            }

            self.memory.deinit();
        }

        pub fn put(self: *Self, key: []const u8, value: T, ttl: u32) !*Entry {
            const allocator = self.allocator;
            const e = try allocator.create(Entry);
            e.* = Entry.init(allocator, key, value, @as(i64, ttl));

            const node = try allocator.create(List.Node);
            node.* = List.Node{ .value = e };

            const expires = std.time.timestamp() + @as(i64, ttl);

            const found = try self.memory.getOrPut(key);

            if (found.found_existing) {
                if (found.value_ptr.*.expires - @as(u32, @intCast(std.time.timestamp())) < 0) {
                    std.debug.print("Warning: put was called on an expired key: {s}\n", .{found.key_ptr.*});
                }

                self.list.remove(found.value_ptr.*.node.?);
                allocator.destroy(found.value_ptr.*.node.?);
                allocator.destroy(found.value_ptr.*);
            } else {
                self.size += 1;
            }

            e.node = node;
            self.list.insert(node);
            e.expires = expires;
            found.value_ptr.* = e;

            if (self.maxSize < self.size) {
                const removedNode = self.list.removeTail();
                const entryToRemove = removedNode.?.value;

                _ = self.memory.remove(entryToRemove.key);
                allocator.destroy(entryToRemove);
                allocator.destroy(removedNode.?);

                self.size -= 1;
            }

            return e;
        }

        pub fn get(self: *Self, key: []const u8) ?*Entry {
            const e = self.memory.get(key) orelse return null;

            if (e.expired()) {
                std.debug.print("Trying to get an expired entry: {s}\n", .{key});
                _ = self.memory.remove(key);
                self.list.remove(e.node.?);
                e.release();
                self.size -= 1;

                return null;
            }

            return e;
        }

        pub fn delete(self: *Self, key: []const u8) bool {
            const e = self.memory.fetchRemove(key);
            const deleted = e orelse return false;

            self.list.remove(deleted.value.node.?);
            deleted.value.release();

            return true;
        }
    };
}

const t = std.testing;

test "cache initial testing loop" {
    const allocator = std.testing.allocator;
    const conf = Config{
        .maxSize = 30,
    };
    var cache = try Cache(u32).init(allocator, conf);
    defer cache.deinit();

    _ = try cache.put("key1", @as(u32, 10), @as(u32, 2));
    _ = try cache.put("key2", @as(u32, 20), @as(u32, 2));
    _ = try cache.put("key3", @as(u32, 30), @as(u32, 3));
    // Change the value for key 'key1'.
    _ = try cache.put("key1", @as(u32, 40), @as(u32, 2));

    var it = cache.memory.iterator();
    while (it.next()) |v| {
        std.debug.print("Changed: {s} -- {d} expires in {d}\n", .{ v.key_ptr.*, v.value_ptr.*.value, v.value_ptr.*.expires });
    }

    std.time.sleep(1e+9 * 3);
    const expired = cache.get("key1");
    try t.expectEqual(expired, null);

    _ = cache.delete("key1");
    _ = cache.delete("key2");
    _ = cache.delete("key3");

    try t.expectEqual(0, cache.memory.count());
}

test "maxSize of the cache is reached" {
    const allocator = std.testing.allocator;
    const conf = Config{
        .maxSize = 2,
    };
    var cache = try Cache(u32).init(allocator, conf);
    defer cache.deinit();

    _ = try cache.put("key1", @as(u32, 10), @as(u32, 2));
    _ = try cache.put("key2", @as(u32, 20), @as(u32, 2));
    _ = try cache.put("key3", @as(u32, 30), @as(u32, 3));

    try t.expectEqual(2, cache.memory.count());

    const notFound = cache.get("key1");
    try t.expectEqual(notFound, null);

    const k2 = cache.get("key2");
    try t.expectEqual(k2.?.value, 20);
    const k3 = cache.get("key3");
    try t.expectEqual(k3.?.value, 30);
}
