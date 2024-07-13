const std = @import("std");
const List = @import("dll.zig").List;
const Entry = @import("entry.zig").Entry;

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

        list: List(T),
        memory: std.StringHashMap(*Entry(T)),

        const Self = @This();

        pub fn init(allocator: Allocator, conf: Config) !Self {
            return .{
                .allocator = allocator,
                .size = 0,
                .maxSize = conf.maxSize,
                .list = List(T).init(),
                .memory = std.StringHashMap(*Entry(T)).init(allocator),
            };
        }

        pub fn put(self: *Self, key: []const u8, value: T, ttl: u32) !void {
            const entry = try self.allocator.create(Entry(T));
            entry.* = Entry(T).init(key, value, ttl);

            const found = try self.memory.getOrPut(key);

            if (found.found_existing) {
                // TODO: Change the value_ptr etc.
                // return null;
                std.debug.print("We shouldn't be here yet...\n", .{});
            } else {
                found.value_ptr.* = entry;
                self.size += 1;
            }
        }

        // pub fn get(self: *Self, key: []const u8) *Entry {}

        // pub fn delete(self: *Self, key: []const u8) *Entry {}
    };
}

test "hashmap" {
    const allocator = std.testing.allocator;
    const conf = Config{
        .maxSize = 30,
    };
    var cache = try Cache(u32).init(allocator, conf);
    defer cache.memory.deinit();

    try cache.put("ahoj1", @as(u32, 10), @as(u32, 100));
    try cache.put("ahoj2", @as(u32, 20), @as(u32, 300));
    try cache.put("ahoj3", @as(u32, 30), @as(u32, 200));

    var it = cache.memory.iterator();

    while (it.next()) |v| {
        std.debug.print("{s} -- {d}\n", .{ v.key_ptr.*, v.value_ptr.*.value });
        cache.allocator.destroy(v.value_ptr.*);
    }
}
