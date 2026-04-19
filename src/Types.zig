const std = @import("std");
const Table = @import("Table.zig");
pub const Element = @import("Element.zig").Element;
pub const FieldType = @import("Element.zig").FieldType;

pub const DBIterator = struct {
    it: std.StringHashMap(Table.Table).Iterator,

    pub fn next(self: *@This()) ?*Table.Table {
        const nextRes = self.it.next() orelse return null;

        return &nextRes.value_ptr.*;
    }
};

pub const TableIterator = struct {
    data: *std.ArrayList(Element),
    index: usize,

    pub fn next(self: *@This()) ?*Element {
        if (self.index >= self.data.items.len) return null;
        const v = &self.data.items[self.index];
        self.index += 1;
        return v;
    }
};

test "Next TableIterator" {
    const allocator = std.testing.allocator;

    var list = std.ArrayList(Element){};
    defer list.deinit(allocator);

    const Player = struct {
        hp: i32,
        name: []const u8,
        score: i32,
    };

    const player1 = Player{ .hp = 100, .name = "Jon", .score = 100 };
    const player2 = Player{ .hp = 42, .name = "Len", .score = 110 };

    var Ep1 = try @import("ElementAdapter.zig").toElement(player1, allocator);
    var Ep2 = try @import("ElementAdapter.zig").toElement(player2, allocator);
    defer Ep1.deinit(allocator);
    defer Ep2.deinit(allocator);

    try list.append(allocator, Ep1);
    try list.append(allocator, Ep2);

    var it = TableIterator{ .data = &list, .index = 0 };

    while (it.next()) |*e| {
        std.debug.print("\n{s}", .{e.*.getAs([]const u8, "name").?});
    }
    std.debug.print("\n", .{});
}
