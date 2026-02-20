const std = @import("std");

pub const FieldType = union(enum) {
    int: i32,
    str: []const u8,
    bool: bool,
    float: f64,
};

pub const Element = struct {
    tname: []const u8,
    field: std.StringHashMap(FieldType),
    scheme: std.ArrayList([]const u8),

    pub fn get(self: @This(), key: []const u8) ?FieldType {
        return self.field.get(key) orelse null;
    }

    pub fn getIndex(self: @This(), index: usize) ?FieldType {
        if (index >= self.keysLen()) return null;
        return self.field.get(self.scheme.items[index]) orelse null;
    }

    pub fn getAs(self: @This(), comptime T: type, key: []const u8) ?T {
        const value = self.field.get(key) orelse return null;
        return switch (value) {
            .int => if (@TypeOf(value.int) == T) value.int else null,
            .str => if (@TypeOf(value.str) == T) value.str else null,
            .bool => if (@TypeOf(value.bool) == T) value.bool else null,
            .float => if (@TypeOf(value.float) == T) value.float else null,
        };
    }

    pub fn getIndexAs(self: @This(), comptime T: type, index: usize) ?T {
        const value = self.field.get(self.scheme.items[index]) orelse return null;
        return switch (value) {
            .int => if (@TypeOf(value.int) == T) value.int else null,
            .str => if (@TypeOf(value.str) == T) value.str else null,
            .bool => if (@TypeOf(value.bool) == T) value.bool else null,
            .float => if (@TypeOf(value.float) == T) value.float else null,
        };
    }

    pub fn set(self: *@This(), key: []const u8, value: FieldType) !void {
        if (!self.field.contains(key)) return error.NotFindField;
        try self.field.put(key, value);
    }

    pub fn setIndex(self: *@This(), index: usize, value: FieldType) !void {
        if (index >= self.keysLen()) return error.InvalidIndex;
        if (!self.field.contains(self.scheme.items[index])) return error.NotFindField;
        try self.field.put(self.scheme.items[index], value);
    }

    pub fn setAs(self: *@This(), comptime T: type, key: []const u8, value: T) !void {
        if (!self.field.contains(key)) return error.NotFindField;
        const ft: FieldType = switch (T) {
            i32 => .{ .int = value },
            []const u8 => .{ .str = value },
            bool => .{ .bool = value },
            f64 => .{ .float = value },
            else => return error.UnsupportedType,
        };
        try self.field.put(key, ft);
    }

    pub fn setIndexAs(self: *@This(), comptime T: type, index: usize, value: T) !void {
        if (index >= self.keysLen()) return error.InvalidIndex;
        if (!self.field.contains(self.scheme.items[index])) return error.NotFindField;
        const ft: FieldType = switch (T) {
            i32 => .{ .int = value },
            []const u8 => .{ .str = value },
            bool => .{ .bool = value },
            f64 => .{ .float = value },
            else => return error.UnsupportedType,
        };
        try self.field.put(self.scheme.items[index], ft);
    }

    pub fn keysLen(self: @This()) usize {
        return self.scheme.items.len;
    }

    pub fn save(self: @This(), writer: *std.fs.File.Writer) !void {
        var w = &writer.interface;

        var iterator = self.field.iterator();

        var next = iterator.next();

        while (next) |e| {
            try w.writeInt(u32, @intCast(e.key_ptr.*.len), .little);
            try w.writeAll(e.key_ptr.*);

            const v = e.value_ptr.*;

            switch (v) {
                .int => {
                    try w.writeByte(0);
                    try w.writeInt(i32, v.int, .little);
                },
                .str => {
                    try w.writeByte(1);
                    try w.writeInt(u32, @intCast(v.str.len), .little);
                    try w.writeAll(v.str);
                },
                .bool => {
                    try w.writeByte(2);
                    try w.writeByte(@intFromBool(v.bool));
                },
                .float => {
                    try w.writeByte(3);
                    try w.writeInt(u64, @bitCast(v.float), .little);
                },
            }

            const peek = iterator.next();

            if (peek) |_| {
                try w.writeByte(1);
            } else {
                try w.writeByte(0);
            }

            next = peek;
        }

        try w.flush();
    }

    pub fn load(self: *@This(), allocator: std.mem.Allocator, reader: *std.fs.File.Reader) !void {
        var r = &reader.interface;
        while (true) {
            const kl = r.takeInt(u32, .little) catch |err| {
                if (err == error.EndOfStream) return;
                return err;
            };
            const ks = try r.take(@intCast(kl));

            const stored_key: []const u8 = ks;

            try self.scheme.append(allocator, stored_key);
            const type_b = try r.take(1);

            switch (type_b[0]) {
                0 => {
                    // int
                    const val = try r.takeInt(i32, .little);
                    try self.field.put(stored_key, .{ .int = val });
                },
                1 => {
                    // str
                    const str_len = try r.takeInt(u32, .little);
                    const str_slice = try r.take(@intCast(str_len));

                    const stored_str: []const u8 = str_slice;

                    try self.field.put(stored_key, .{ .str = stored_str });
                },
                2 => {
                    // bool
                    const bool_b = try r.take(1);
                    const b = bool_b[0] != 0;
                    try self.field.put(stored_key, .{ .bool = b });
                },
                3 => {
                    // float
                    const int = try r.takeInt(u64, .little);
                    const val: f64 = @bitCast(int);
                    try self.field.put(stored_key, .{ .float = val });
                },
                else => return error.InvalidFormat,
            }

            const n = try r.take(1);

            if (n[0] == 0) {
                return;
            }
        }
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        self.field.deinit();
        self.scheme.deinit(allocator);
    }
};

pub const TableIterator = struct {
    data: *std.ArrayList(Element),
    index: usize,

    pub fn next(self: *@This()) ?Element {
        if (self.index >= self.data.items.len) return null;
        const v = self.data.items[self.index];
        self.index += 1;
        return v;
    }
};

test "Element" {
    const User = struct {
        id: i32,
        name: []const u8,
    };

    const user = User{ .id = 0, .name = "Jon" };

    const allocator = std.testing.allocator;

    var e = try @import("ElementAdapter.zig").toElement(user, allocator);
    defer e.deinit(allocator);

    try e.setAs([]const u8, "name", "JDH");
}

test "Element save" {
    var file = try std.fs.cwd().createFile("test_element", .{});
    defer file.close();

    var buff: [1024]u8 = undefined;

    var writer = file.writer(&buff);

    const User = struct {
        id: i32,
        name: []const u8,
    };

    const user = User{ .id = 136, .name = "Jon" };

    const allocator = std.testing.allocator;

    var Euser = try @import("ElementAdapter.zig").toElement(user, allocator);
    defer Euser.deinit(allocator);

    try Euser.save(&writer);
}

test "Element load" {
    var file = try std.fs.cwd().openFile("test_element", .{});
    defer file.close();

    var buff: [1024]u8 = undefined;

    var reader = file.reader(&buff);

    const User = struct {
        id: i32,
        name: []const u8,
    };

    const allocator = std.testing.allocator;

    var Euser = Element{
        .tname = @typeName(User),
        .field = std.StringHashMap(FieldType).init(allocator),
        .scheme = std.ArrayList([]const u8){},
    };
    defer Euser.deinit(allocator);

    try Euser.load(
        allocator,
        &reader,
    );

    if (Euser.getAs([]const u8, "name") == null) {
        return error.InvalidLoad;
    }

    std.debug.print("\n{s}\n", .{Euser.getAs([]const u8, "name").?});
}

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

    const Ep1 = try @import("ElementAdapter.zig").toElement(player1, allocator);
    const Ep2 = try @import("ElementAdapter.zig").toElement(player2, allocator);

    try list.append(allocator, Ep1);
    try list.append(allocator, Ep2);

    var it = TableIterator{ .data = &list, .index = 0 };

    while (it.next()) |*e| {
        std.debug.print("\n{s}", .{e.getAs([]const u8, "name").?});
        @constCast(e).deinit();
    }
    std.debug.print("\n", .{});
}
