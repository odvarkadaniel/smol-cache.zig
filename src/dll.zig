const std = @import("std");
const t = std.testing;

pub fn List(comptime T: type) type {
    return struct {
        pub const Node = struct {
            prev: ?*Node = null,
            succ: ?*Node = null,
            value: T,
        };

        head: ?*Node,
        tail: ?*Node,

        const Self = @This();

        pub fn init() Self {
            return .{
                .head = null,
                .tail = null,
            };
        }

        // insert prepends a new node to the DLL.
        pub fn insert(self: *Self, node: *Node) void {
            if (self.head) |head| {
                head.prev = node;
                node.succ = head;
                self.head = node;
            } else {
                self.head = node;
                self.tail = node;
            }
            node.prev = null;
        }

        // remove deletes a specified node from the DLL.
        pub fn remove(self: *Self, node: *Node) void {
            if (node.prev) |prev| {
                prev.succ = node.succ;
            } else {
                self.head = node.succ;
            }

            if (node.succ) |succ| {
                succ.prev = node.prev;
            } else {
                self.tail = node.prev;
            }
        }

        // removeTail pops out the tail of the DLL
        // if there is one.
        pub fn removeTail(self: *Self) ?*Node {
            if (self.tail) |tail| {
                if (tail.prev) |prev| {
                    self.tail = prev;
                    prev.succ = null;
                } else {
                    self.tail = null;
                    self.head = null;
                }

                // Remove the references to other nodes.
                tail.prev = null;
                tail.succ = null;

                return tail;
            }

            return null;
        }
    };
}

fn checkDLL(dll: List(i32), expected: []const i32) !void {
    var node = dll.tail;
    var i: usize = expected.len;

    while (i > 0) : (i -= 1) {
        try t.expectEqual(expected[i - 1], node.?.value);
        node = node.?.prev;
    }

    try t.expectEqual(null, node);
}

test "insert and delete nodes from DLL" {
    var dll = List(i32).init();

    var node1 = List(i32).Node{ .value = 1 };
    dll.insert(&node1);
    try checkDLL(dll, &.{1});

    var node2 = List(i32).Node{ .value = 2 };
    dll.insert(&node2);
    try checkDLL(dll, &.{ 2, 1 });

    dll.remove(&node1);
    try checkDLL(dll, &.{2});

    dll.remove(&node2);
    try checkDLL(dll, &.{});

    // Try to delete a non-existent node from the DLL.
    dll.remove(&node2);
    try checkDLL(dll, &.{});

    var node3 = List(i32).Node{ .value = 3 };
    dll.insert(&node3);
    try checkDLL(dll, &.{3});

    dll.insert(&node2);
    try checkDLL(dll, &.{ 2, 3 });

    // Remove the element in the middle.
    dll.insert(&node1);
    try checkDLL(dll, &.{ 1, 2, 3 });

    dll.remove(&node2);
    try checkDLL(dll, &.{ 1, 3 });
}

test "delete tail from DLL" {
    var dll = List(i32).init();

    // Removing tail on empty DLL should return null.
    var tail = dll.removeTail();
    try t.expectEqual(null, tail);

    var node1 = List(i32).Node{ .value = 1 };
    var node2 = List(i32).Node{ .value = 2 };
    var node3 = List(i32).Node{ .value = 3 };

    dll.insert(&node1);
    dll.insert(&node2);
    dll.insert(&node3);

    tail = dll.removeTail();
    try t.expectEqual(&node1, tail);

    try checkDLL(dll, &.{ 3, 2 });
}
