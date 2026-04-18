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
    var scheme = std.ArrayList([]const u8){};
    const info = @typeInfo(T);

    inline for (info.@"struct".fields) |field| {
        const name = field.name;
        const value = @field(a, name);

        try scheme.append(allocator, name);

        const putedData = switch (field.type) {
            i8 => Types.FieldType{ .int8 = value },
            i16 => Types.FieldType{ .int16 = value },
            i32 => Types.FieldType{ .int32 = value },
            i64 => Types.FieldType{ .int64 = value },
            u8 => Types.FieldType{ .uint8 = value },
            u16 => Types.FieldType{ .uint16 = value },
            u32 => Types.FieldType{ .uint32 = value },
            u64 => Types.FieldType{ .uint64 = value },
            []const u8 => Types.FieldType{ .str = value },
            bool => Types.FieldType{ .bool = value },
            f64 => Types.FieldType{ .float = value },
            else => return error.InvalidType,
        };

        try fields.put(name, putedData);
    }

    return Types.Element{ .tname = tname, .field = fields, .scheme = scheme };
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
    defer Euser.deinit(allocator);

    if (Euser.getAs(i32, "id") != 0) {
        return error.InvalidID;
    }
    if (!std.mem.eql(u8, Euser.getAs([]const u8, "name").?, "Jon")) {
        return error.InvalidName;
    }
}
