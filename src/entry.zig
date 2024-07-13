pub fn Entry(comptime T: type) type {
    return struct {
        key: []const u8,
        value: T,
        ttl: u32,
        // What about size of the item to track size < max_size?

        const Self = @This();

        pub fn init(key: []const u8, value: T, ttl: u32) Self {
            return .{
                .key = key,
                .value = value,
                .ttl = ttl,
            };
        }
    };
}
