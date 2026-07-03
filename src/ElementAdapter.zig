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
    var scheme = std.ArrayList([]const u8).empty;
    const info = @typeInfo(T);

    inline for (info.@"struct".fields) |field| {
        const name = field.name;
        const value = @field(a, name);

        const putedData: Types.FieldType = switch (field.type) {
            i8 => Types.FieldType{ .int8 = value },
            i16 => Types.FieldType{ .int16 = value },
            i32 => Types.FieldType{ .int32 = value },
            i64 => Types.FieldType{ .int64 = value },
            u8 => Types.FieldType{ .uint8 = value },
            u16 => Types.FieldType{ .uint16 = value },
            u32 => Types.FieldType{ .uint32 = value },
            u64 => Types.FieldType{ .uint64 = value },
            []const u8 => Types.FieldType{ .str = try allocator.dupe(u8, value) },
            bool => Types.FieldType{ .bool = value },
            f64 => Types.FieldType{ .float = value },
            []const i8 => .{ .array = .{ .i8 = try allocator.dupe(i8, value) } },
            []const i16 => .{ .array = .{ .i16 = try allocator.dupe(i16, value) } },
            []const i32 => .{ .array = .{ .i32 = try allocator.dupe(i32, value) } },
            []const i64 => .{ .array = .{ .i64 = try allocator.dupe(i64, value) } },
            []const u16 => .{ .array = .{ .u16 = try allocator.dupe(u16, value) } },
            []const u32 => .{ .array = .{ .u32 = try allocator.dupe(u32, value) } },
            []const u64 => .{ .array = .{ .u64 = try allocator.dupe(u64, value) } },
            []const []const u8 => field: {
                var strings = try allocator.alloc([]const u8, value.len);
                errdefer {
                    for (strings) |s| allocator.free(s);
                    allocator.free(strings);
                }
                for (value, 0..) |str, i| {
                    strings[i] = try allocator.dupe(u8, str);
                }
                break :field .{ .array = .{ .str = strings } };
            },
            []const bool => .{ .array = .{ .bool = try allocator.dupe(bool, value) } },
            []const f64 => .{ .array = .{ .f64 = try allocator.dupe(f64, value) } },
            else => {
                std.debug.print("TYPE ERROR: {any}\n", .{field.type});
                return error.InvalidType;
            },
        };

        try fields.put(name, putedData);
    }

    return Types.Element{
        .tname = tname,
        .field = fields,
        .scheme = &scheme,
        .allocator = allocator,
    };
}

test "to element" {
    const User = struct {
        id: i32,
        name: []const u8,
    };

    const user = User{ .id = 0, .name = "Jon" };

    var gpa = std.heap.DebugAllocator(.{}){};
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
