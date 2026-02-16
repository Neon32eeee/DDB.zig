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

    var fileds = std.StringHashMap(Types.FiledType).init(allocator);
    const info = @typeInfo(T);

    inline for (info.@"struct".fields) |filed| {
        const name = filed.name;
        const value = @field(a, name);

        if (filed.type == i32) {
            try fileds.put(name, Types.FiledType{ .int = value });
        } else if (filed.type == []const u8) {
            try fileds.put(name, Types.FiledType{ .str = value });
        } else if (filed.type == bool) {
            try fileds.put(name, Types.FiledType{ .bool = value });
        } else if (filed.type == f64) {
            try fileds.put(name, Types.FiledType{ .float = value });
        } else {
            return error.InvalidType;
        }
    }

    return Types.Element{ .tmane = tname, .filed = fileds };
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

    if (Euser.getInt("id") != 0) {
        return error.InvalidID;
    }
    if (!std.mem.eql(u8, Euser.getStr("name").?, "Jon")) {
        return error.InvalidName;
    }
}
