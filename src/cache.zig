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
        const List = dll.List(T);

        pub fn init(allocator: Allocator, conf: Config) !Self {
            return .{
                .allocator = allocator,
                .size = 0,
                .maxSize = conf.maxSize,
                .list = List.init(),
                .memory = std.StringHashMap(*Entry).init(allocator),
            };
        }

        pub fn put(self: *Self, key: []const u8, value: T, ttl: u32) !*Entry {
            const e = try self.allocator.create(Entry);
            e.* = Entry.init(key, value, @as(i64, ttl));

            var node = List.Node{ .value = value };

            const expires = std.time.timestamp() + @as(i64, ttl);

            const found = try self.memory.getOrPut(key);

            if (found.found_existing) {
                if (found.value_ptr.*.expires - @as(u32, @intCast(std.time.timestamp())) < 0) {
                    std.debug.print("The entry is expired!\n", .{});

                    return e;
                }

                found.value_ptr.*.node.?.value = value;
            } else {
                self.size += 1;
            }

            e.node = &node;
            self.list.insert(&node);
            e.expires = expires;
            found.value_ptr.* = e;

            return e;
        }

        pub fn get(self: *Self, key: []const u8) ?*Entry {
            const e = self.memory.get(key) orelse return null;

            if (e.expired()) {
                // TODO: We will need to free memory.
                std.debug.print("EXPIRED VALUE!\n", .{});
                return null;
            }

            return e;
        }

        // pub fn delete(self: *Self, key: []const u8) *Entry {}
    };
}

const t = std.testing;

test "hashmap initial testing loop" {
    const allocator = std.testing.allocator;
    const conf = Config{
        .maxSize = 30,
    };
    var cache = try Cache(u32).init(allocator, conf);
    defer cache.memory.deinit();

    // _ = try cache.put("ahoj1", @as(u32, 10), @as(u32, 1));
    // std.time.sleep(3e+9);
    // std.debug.print("Done sleeping!", .{});
    _ = try cache.put("ahoj1", @as(u32, 10), @as(u32, 1));
    _ = try cache.put("ahoj2", @as(u32, 20), @as(u32, 2));
    _ = try cache.put("ahoj3", @as(u32, 30), @as(u32, 3));

    const e = cache.get("ahoj1");
    if (e) |good| {
        std.debug.print("{s} -- {d}\n", .{ good.key, good.value });
    }

    std.time.sleep(1e+9 * 3);
    try t.expectEqual(cache.get("ahoj1"), null);

    var it = cache.memory.iterator();

    while (it.next()) |v| {
        std.debug.print("{s} -- {d} expires in {d}\n", .{ v.key_ptr.*, v.value_ptr.*.value, v.value_ptr.*.expires });
        // const e = v.value_ptr.*;
        cache.allocator.destroy(v.value_ptr.*);
    }
}
