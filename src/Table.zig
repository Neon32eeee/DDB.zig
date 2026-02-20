const std = @import("std");
const Types = @import("Types.zig");

pub const Table = struct {
    rows: std.ArrayList(Types.Element),
    allocator: std.mem.Allocator,
    tname: []const u8,
    data_buffer: ?[]u8 = null,

    pub fn init(
        tname: []const u8,
        allocator: std.mem.Allocator,
    ) Table {
        return .{
            .rows = std.ArrayList(Types.Element){},
            .allocator = allocator,
            .tname = tname,
        };
    }

    pub fn append(self: *Table, row: Types.Element) !void {
        if (!std.mem.eql(u8, row.tname, self.tname)) {
            std.debug.print("\n{s}\n", .{self.tname});
            return error.InvalidType;
        }
        try self.rows.append(self.allocator, row);
    }

    pub fn remove(self: *@This(), index: usize) !void {
        if (index >= self.len()) return error.InvalidIndex;
        self.rows.items[index].deinit();
        _ = self.rows.orderedRemove(index);
    }

    pub fn get(self: Table, index: usize) ?Types.Element {
        if (self.len() <= index) return null;
        return self.rows.items[index];
    }

    pub fn iterator(self: *@This()) Types.TableIterator {
        return Types.TableIterator(.{ .data = &self.rows, .index = 0 });
    }

    pub fn len(self: @This()) usize {
        return self.rows.items.len;
    }

    pub fn clear(self: *@This()) void {
        if (self.len() == 0) return;
        self.rows.clearAndFree(self.allocator);
    }

    pub fn deinit(self: *@This()) void {
        for (self.rows.items) |*element| {
            element.deinit(self.allocator);
        }
        self.rows.deinit(self.allocator);

        if (self.data_buffer) |b| self.allocator.free(b);
    }
};

test "Add row" {
    const User = struct {
        id: i32,
        name: []const u8,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tb = Table.init(@typeName(User), allocator);
    defer tb.deinit();

    const user = User{ .id = 0, .name = "Jon" };

    const Euser = try @import("ElementAdapter.zig").toElement(user, allocator);

    try tb.append(Euser);
}

test "Get index row" {
    const User = struct {
        id: i32,
        name: []const u8,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tb = Table.init(@typeName(User), allocator);
    defer tb.deinit();

    const user = User{ .id = 0, .name = "Jon" };

    const Euser = try @import("ElementAdapter.zig").toElement(user, allocator);

    try tb.append(Euser);

    const get = tb.get(0) orelse unreachable;
    std.debug.print("\nid:{d}\nname:{s}\n", .{ get.getAs(i32, "id").?, get.getAs([]const u8, "name").? });
}

test "Clear Table" {
    const User = struct {
        id: i32,
        name: []const u8,
    };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var tb = Table.init(@typeName(User), allocator);
    defer tb.deinit();

    const user = User{ .id = 0, .name = "Jon" };

    const Euser = try @import("ElementAdapter.zig").toElement(user, allocator);

    try tb.append(Euser);

    tb.clear();

    try tb.append(Euser);
}
