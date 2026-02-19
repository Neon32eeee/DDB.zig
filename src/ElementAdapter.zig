const std = @import("std");
const Types = @import("Types.zig");

pub fn toElement(a: anytype, allocator: std.mem.Allocator) !Types.Element {
    const T = @TypeOf(a);

    comptime {
        if (@typeInfo(T) != .@"struct") {
            @compileError("Invalid Type");
        }
    }

    const tname = @typeName(T);

    var fields = std.StringHashMap(Types.FieldType).init(allocator);
    const info = @typeInfo(T);

    inline for (info.@"struct".fields) |field| {
        const name = field.name;
        const value = @field(a, name);

        if (field.type == i32) {
            try fields.put(name, Types.FieldType{ .int = value });
        } else if (field.type == []const u8) {
            try fields.put(name, Types.FieldType{ .str = value });
        } else if (field.type == bool) {
            try fields.put(name, Types.FieldType{ .bool = value });
        } else if (field.type == f64) {
            try fields.put(name, Types.FieldType{ .float = value });
        } else {
            return error.InvalidType;
        }
    }

    return Types.Element{ .tname = tname, .field = fields };
}

test "to element" {
    const User = struct {
        id: i32,
        name: []const u8,
    };

    const user = User{ .id = 0, .name = "Jon" };

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var Euser = try toElement(user, allocator);
    defer Euser.deinit();

    if (Euser.getAs(i32, "id") != 0) {
        return error.InvalidID;
    }
    if (!std.mem.eql(u8, Euser.getAs([]const u8, "name").?, "Jon")) {
        return error.InvalidName;
    }
}
