const std = @import("std");
const ddb = @import("ddb");

pub fn main(init: std.process.Init) !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const io = init.io;

    var db = try ddb.DB().init("DB.db", allocator, io);
    defer db.deinit();

    try db.load();

    var it = db.tables.iterator();

    while (it.next()) |t| {
        const k = t.key_ptr.*;
        var v = t.value_ptr.*;

        std.debug.print("Name table:{s}\n  Table type:{s}\n", .{ k, v.tname });
        var tit = v.iterator();

        var n: usize = 0;
        while (tit.next()) |e| {
            n += 1;

            std.debug.print("{d}|", .{n});
            for (0..e.keysLen()) |i| {
                const name = e.scheme.items[i];
                std.debug.print("{s}:", .{name});
                const val = e.getIndex(i).?;
                switch (val) {
                    .i32 => |value| std.debug.print("{d} ", .{value}),
                    .str => |value| std.debug.print("{s} ", .{value}),
                    .bool => |value| std.debug.print("bool: {s} ", .{(if (value) "true" else "false")}),
                    .float => |value| std.debug.print("float: {:.6} ", .{value}),
                    else => {
                        std.debug.print("Support coming soon ", .{});
                    },
                }
            }
            std.debug.print("\n", .{});
        }
    }
}
