const std = @import("std");
const ddb = @import("ddb");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = try ddb.DB().init("DB", allocator);
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
                    .int => |value| std.debug.print("{d} ", .{value}),
                    .str => |value| std.debug.print("{s} ", .{value}),
                    .bool => |value| std.debug.print("bool: {s} ", .{(if (value) "true" else "false")}),
                    .float => |value| std.debug.print("float: {:.6} ", .{value}),
                }
            }
            std.debug.print("\n", .{});
        }
    }
}
