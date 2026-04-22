const std = @import("std");

pub const FieldType = union(enum) {
    int8: i8,
    int16: i16,
    int32: i32,
    int64: i64,
    uint8: u8,
    uint16: u16,
    uint32: u32,
    uint64: u64,
    str: []const u8,
    bool: bool,
    float: f64,
    array: union(enum) {
        i8: []const i8,
        i16: []const i16,
        i32: []const i32,
        i64: []const i64,
        u16: []const u16,
        u32: []const u32,
        u64: []const u64,
        str: []const []const u8,
        bool: []const bool,
        f64: []const f64,
    },
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
            inline .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .str, .bool, .float => |payload| if (@TypeOf(payload) == T) payload else null,

            .array => |arr| switch (arr) {
                inline .i8, .i16, .i32, .i64, .u16, .u32, .u64, .str, .bool, .f64 => |slice| if (@TypeOf(slice) == T) slice else null,
            },
        };
    }

    pub fn getIndexAs(self: @This(), comptime T: type, index: usize) ?T {
        const value = self.field.get(self.scheme.items[index]) orelse return null;
        return switch (value) {
            inline .int8, .int16, .int32, .int64, .uint8, .uint16, .uint32, .uint64, .str, .bool, .float => |payload| if (@TypeOf(payload) == T) payload else null,

            .array => |arr| switch (arr) {
                inline .i8, .i16, .i32, .i64, .u16, .u32, .u64, .str, .bool, .f64 => |slice| if (@TypeOf(slice) == T) slice else null,
            },
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
            i8 => .{ .int8 = value },
            i16 => .{ .int16 = value },
            i32 => .{ .int32 = value },
            i64 => .{ .int64 = value },
            u8 => .{ .uint8 = value },
            u16 => .{ .uint16 = value },
            u32 => .{ .uint32 = value },
            u64 => .{ .uint64 = value },
            []const u8 => .{ .str = value },
            bool => .{ .bool = value },
            f64 => .{ .float = value },

            []const i8 => .{ .array = .{ .i8 = value } },
            []const i16 => .{ .array = .{ .i16 = value } },
            []const i32 => .{ .array = .{ .i32 = value } },
            []const i64 => .{ .array = .{ .i64 = value } },
            []const u16 => .{ .array = .{ .u16 = value } },
            []const u32 => .{ .array = .{ .u32 = value } },
            []const u64 => .{ .array = .{ .u64 = value } },
            []const []const u8 => .{ .array = .{ .str = value } },
            []const bool => .{ .array = .{ .bool = value } },
            []const f64 => .{ .array = .{ .f64 = value } },

            else => return error.UnsupportedType,
        };

        try self.field.put(key, ft);
    }

    pub fn setIndexAs(self: *@This(), comptime T: type, index: usize, value: T) !void {
        if (index >= self.keysLen()) return error.InvalidIndex;
        if (!self.field.contains(self.scheme.items[index])) return error.NotFindField;
        const ft: FieldType = switch (T) {
            i8 => .{ .int8 = value },
            i16 => .{ .int16 = value },
            i32 => .{ .int32 = value },
            i64 => .{ .int64 = value },
            u8 => .{ .uint8 = value },
            u16 => .{ .uint16 = value },
            u32 => .{ .uint32 = value },
            u64 => .{ .uint64 = value },
            []const u8 => .{ .str = value },
            bool => .{ .bool = value },
            f64 => .{ .float = value },

            []const i8 => .{ .array = .{ .i8 = value } },
            []const i16 => .{ .array = .{ .i16 = value } },
            []const i32 => .{ .array = .{ .i32 = value } },
            []const i64 => .{ .array = .{ .i64 = value } },
            []const u8 => .{ .array = .{ .u8 = value } },
            []const u16 => .{ .array = .{ .u16 = value } },
            []const u32 => .{ .array = .{ .u32 = value } },
            []const u64 => .{ .array = .{ .u64 = value } },
            []const []const u8 => .{ .array = .{ .str = value } },
            []const bool => .{ .array = .{ .bool = value } },
            []const f64 => .{ .array = .{ .f64 = value } },

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
                .int32 => {
                    try w.writeByte(0);
                    try w.writeInt(i32, v.int32, .little);
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
                .int8 => {
                    try w.writeByte(4);
                    try w.writeInt(i8, v.int8, .little);
                },
                .int16 => {
                    try w.writeByte(5);
                    try w.writeInt(i16, v.int16, .little);
                },
                .int64 => {
                    try w.writeByte(6);
                    try w.writeInt(i64, v.int64, .little);
                },
                .uint8 => {
                    try w.writeByte(7);
                    try w.writeInt(u8, v.uint8, .little);
                },
                .uint16 => {
                    try w.writeByte(8);
                    try w.writeInt(u16, v.uint16, .little);
                },
                .uint32 => {
                    try w.writeByte(9);
                    try w.writeInt(u32, v.uint32, .little);
                },
                .uint64 => {
                    try w.writeByte(10);
                    try w.writeInt(u64, v.uint64, .little);
                },
                .array => |arr| {
                    try w.writeByte(11);

                    switch (arr) {
                        .i8 => {
                            try w.writeByte(0);
                            try writeArray(i8, w, arr.i8);
                        },
                        .i16 => {
                            try w.writeByte(1);
                            try writeArray(i16, w, arr.i16);
                        },
                        .i32 => {
                            try w.writeByte(2);
                            try writeArray(i32, w, arr.i32);
                        },
                        .i64 => {
                            try w.writeByte(3);
                            try writeArray(i64, w, arr.i64);
                        },
                        .u16 => {
                            try w.writeByte(4);
                            try writeArray(u16, w, arr.u16);
                        },
                        .u32 => {
                            try w.writeByte(5);
                            try writeArray(u32, w, arr.u32);
                        },
                        .u64 => {
                            try w.writeByte(6);
                            try writeArray(u64, w, arr.u64);
                        },
                        .str => {
                            try w.writeByte(7);
                            try writeStrArray(w, arr.str);
                        },
                        .bool => {
                            try w.writeByte(8);
                            try writeBoolArray(w, arr.bool);
                        },
                        .f64 => {
                            try w.writeByte(9);
                            try writeFloatArray(w, arr.f64);
                        },
                    }
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

    fn writeArray(comptime T: type, w: *std.Io.Writer, slice: []const T) !void {
        try w.writeInt(u32, @intCast(slice.len), .little);
        for (slice) |item| {
            try w.writeInt(T, item, .little);
        }
    }

    fn writeFloatArray(w: *std.Io.Writer, slice: []const f64) !void {
        try w.writeInt(u32, @intCast(slice.len), .little);
        for (slice) |item| {
            try w.writeInt(u64, @bitCast(item), .little);
        }
    }

    fn writeStrArray(w: *std.Io.Writer, slice: []const []const u8) !void {
        try w.writeInt(u32, @intCast(slice.len), .little);
        for (slice) |s| {
            try w.writeInt(u32, @intCast(s.len), .little);
            try w.writeAll(s);
        }
    }

    fn writeBoolArray(w: *std.Io.Writer, slice: []const bool) !void {
        try w.writeInt(u32, @intCast(slice.len), .little);
        for (slice) |b| {
            try w.writeByte(@intFromBool(b));
        }
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
                    // int32
                    const val = try r.takeInt(i32, .little);
                    try self.field.put(stored_key, .{ .int32 = val });
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
                    const int32 = try r.takeInt(u64, .little);
                    const val: f64 = @bitCast(int32);
                    try self.field.put(stored_key, .{ .float = val });
                },
                4 => {
                    // int8
                    const val = try r.takeInt(i8, .little);
                    try self.field.put(stored_key, .{ .int8 = val });
                },
                5 => {
                    // int16
                    const val = try r.takeInt(i16, .little);
                    try self.field.put(stored_key, .{ .int16 = val });
                },
                6 => {
                    // int64
                    const val = try r.takeInt(i64, .little);
                    try self.field.put(stored_key, .{ .int64 = val });
                },
                7 => {
                    // uint8
                    const val = try r.takeInt(u8, .little);
                    try self.field.put(stored_key, .{ .uint8 = val });
                },
                8 => {
                    // uint16
                    const val = try r.takeInt(u16, .little);
                    try self.field.put(stored_key, .{ .uint16 = val });
                },
                9 => {
                    // uint32
                    const val = try r.takeInt(u32, .little);
                    try self.field.put(stored_key, .{ .uint32 = val });
                },
                10 => {
                    // uint64
                    const val = try r.takeInt(u64, .little);
                    try self.field.put(stored_key, .{ .uint64 = val });
                },
                11 => {
                    // array
                    const type_c = try r.take(1);
                    const len = try r.takeInt(u32, .little);

                    switch (type_c[0]) {
                        0 => {
                            const v = try loadArray(i8, r, len, allocator);
                            try self.field.put(stored_key, .{ .array = .{ .i8 = v } });
                        },
                        1 => {
                            const v = try loadArray(i16, r, len, allocator);
                            try self.field.put(stored_key, .{ .array = .{ .i16 = v } });
                        },
                        2 => {
                            const v = try loadArray(i32, r, len, allocator);
                            try self.field.put(stored_key, .{ .array = .{ .i32 = v } });
                        },
                        3 => {
                            const v = try loadArray(i64, r, len, allocator);
                            try self.field.put(stored_key, .{ .array = .{ .i64 = v } });
                        },
                        4 => {
                            const v = try loadArray(u16, r, len, allocator);
                            try self.field.put(stored_key, .{ .array = .{ .u16 = v } });
                        },
                        5 => {
                            const v = try loadArray(u32, r, len, allocator);
                            try self.field.put(stored_key, .{ .array = .{ .u32 = v } });
                        },
                        6 => {
                            const v = try loadArray(u64, r, len, allocator);
                            try self.field.put(stored_key, .{ .array = .{ .u64 = v } });
                        },
                        7 => {
                            const v = try loadStrArray(r, len, allocator);
                            try self.field.put(stored_key, .{ .array = .{ .str = v } });
                        },
                        8 => {
                            const v = try loadBoolArray(r, len, allocator);
                            try self.field.put(stored_key, .{ .array = .{ .bool = v } });
                        },
                        9 => {
                            const v = try loadFloatArray(r, len, allocator);
                            try self.field.put(stored_key, .{ .array = .{ .f64 = v } });
                        },
                        else => return error.InvalidFormat,
                    }
                },

                else => return error.InvalidFormat,
            }

            const n = try r.take(1);

            if (n[0] == 0) {
                return;
            }
        }
    }

    fn loadArray(comptime T: type, r: *std.Io.Reader, len: u32, allocator: std.mem.Allocator) ![]T {
        const val = try allocator.alloc(T, @intCast(len));
        for (0..len) |i| {
            const v = try r.takeInt(T, .little);
            val[i] = v;
        }
        return val;
    }

    fn loadStrArray(r: *std.Io.Reader, len: u32, allocator: std.mem.Allocator) ![][]const u8 {
        const val = try allocator.alloc([]const u8, @intCast(len));
        for (0..len) |i| {
            const l = try r.takeInt(u32, .little);
            const s = try r.take(@intCast(l));
            val[i] = s;
        }
        return val;
    }

    fn loadBoolArray(r: *std.Io.Reader, len: u32, allocator: std.mem.Allocator) ![]bool {
        const val = try allocator.alloc(bool, @intCast(len));
        for (0..len) |i| {
            const bool_b = try r.take(1);
            const b = bool_b[0] != 0;
            val[i] = b;
        }
        return val;
    }

    fn loadFloatArray(r: *std.Io.Reader, len: u32, allocator: std.mem.Allocator) ![]f64 {
        const val = try allocator.alloc(f64, @intCast(len));
        for (0..len) |i| {
            const int32 = try r.takeInt(u64, .little);
            const v: f64 = @bitCast(int32);
            val[i] = v;
        }
        return val;
    }

    pub fn clone(
        self: @This(),
    ) @This() {
        return Element{
            .tname = self.tname,
            .field = self.field,
            .scheme = self.scheme,
        };
    }

    pub fn deinit(self: *@This(), allocator: std.mem.Allocator) void {
        var it = self.field.iterator();
        while (it.next()) |entry| {
            switch (entry.value_ptr.*) {
                .array => |arr| {
                    switch (arr) {
                        .i8 => |slice| allocator.free(slice),
                        .i16 => |slice| allocator.free(slice),
                        .i32 => |slice| allocator.free(slice),
                        .i64 => |slice| allocator.free(slice),
                        .u16 => |slice| allocator.free(slice),
                        .u32 => |slice| allocator.free(slice),
                        .u64 => |slice| allocator.free(slice),
                        .bool => |slice| allocator.free(slice),
                        .f64 => |slice| allocator.free(slice),
                        .str => |slice| {
                            for (slice) |s| allocator.free(s);
                            allocator.free(slice);
                        },
                    }
                },
                else => {},
            }
        }

        self.field.deinit();
        self.scheme.deinit(allocator);
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

test "Element array" {
    const User = struct {
        id: i32,
        birthday: []const i32,
    };

    // Save
    const allocator = std.testing.allocator;
    const birthday_data = try allocator.alloc(i32, 3);
    birthday_data[0] = 1999;
    birthday_data[1] = 11;
    birthday_data[2] = 11;

    const user = User{ .id = 136, .birthday = birthday_data };

    var Euser = try @import("ElementAdapter.zig").toElement(user, allocator);
    defer Euser.deinit(allocator);

    var file = try std.fs.cwd().createFile("test_element", .{});
    defer file.close();

    var buff: [1024]u8 = undefined;
    var writer = file.writer(&buff);
    try Euser.save(&writer);

    // Load
    var loadFile = try std.fs.cwd().openFile("test_element", .{});

    var buff2: [1024]u8 = undefined;
    var reader = loadFile.reader(&buff2);

    var loaded = Element{
        .tname = @typeName(User),
        .field = std.StringHashMap(FieldType).init(allocator),
        .scheme = std.ArrayList([]const u8){},
    };
    defer loaded.deinit(allocator);

    try loaded.load(allocator, &reader);

    const loaded_birthday = loaded.getAs([]const i32, "birthday").?;
    try std.testing.expectEqualSlices(i32, birthday_data, loaded_birthday);
}
