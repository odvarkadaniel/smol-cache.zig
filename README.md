# Simple LRU Cache In Zig
This small LRU Cache supports only three operations:
- `put` will return `null` whenever the key is not present in the cache or when the key is expired.
- `get` will return `null` whenever the key is not present in the cache or when the key is expired.
- `delete` removes an entry from the cache (if it exists).

## Put
This operation has the following signature:
```zig
pub fn put(self: *Self, key: []const u8, value: T, ttl: u32) !*Entry
```
The only configuration the cache provides is the `ttl` argument which specifies the length of life of the value in the cache.
After the call, we return the entry back to the user.

## Get
The `Get` operation will either return the entry back to the user or it will return `null` (key doesn't exist or the entry is expired).
```zig
pub fn get(self: *Self, key: []const u8) ?*Entry
```

## Delete
The `Delete` operation simply removes an entry from the cache and returns `true`. If a user tries to delete an entry that is not present in the cache, the operation returns `false`.
```zig
pub fn delete(self: *Self, key: []const u8) bool
```

## Examples
```zig
const conf = Config{
    .maxSize = 30,
};
var cache = try Cache(u32).init(allocator, conf);
defer cache.deinit();

_ = try cache.put("key1", @as(u32, 10), @as(u32, 2));

if (cache.get("key1")) |key1| {
    defer key1.release();
    // ...
} else {
    // Not in the cache.
}

_ = cache.delete("key1");
```
