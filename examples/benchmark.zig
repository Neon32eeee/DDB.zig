const std = @import("std");
const ddb = @import("ddb");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // инициализация базы
    var db = try ddb.DB().init("bench.db", allocator);
    defer db.deinit();

    // создаём таблицу users
    const Users = struct {
        id: i32,
        name: []const u8,
    };
    try db.createTable("users", Users);

    // замер времени
    const start = std.time.nanoTimestamp();

    const table = db.getTable("users").?;

    const n: usize = 1000;
    for (0..n) |i| {
        const row = Users{
            .id = @intCast(i),
            .name = "test",
        };
        const erow = try ddb.Adapter.toElement(row, allocator);
        try table.append(erow);
    }

    const end = std.time.nanoTimestamp();

    const total_ns: i128 = end - start;
    const avg_ns: i128 = @divTrunc(total_ns, 1000);

    const total_sec: f64 = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(std.time.ns_per_s));
    const avg_sec: f64 = @as(f64, @floatFromInt(avg_ns)) / @as(f64, @floatFromInt(std.time.ns_per_s));

    std.debug.print(
        "1000 insert ops: {d:.6} s total, {d:.6} s per op\n",
        .{ total_sec, avg_sec },
    );
}
