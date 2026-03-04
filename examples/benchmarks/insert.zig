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

    var table = db.getTable("users").?;

    var increase: usize = 1;
    inline for (0..3) |_| {
        table.clear();
        const n: usize = 1000 * increase;
        increase += if (increase == 1) 9 else 90;

        var elements = try allocator.alloc(ddb.Element, n);
        defer allocator.free(elements);

        const start = std.time.nanoTimestamp();

        for (0..1000) |_| {
            table.clear();

            for (0..n) |i| {
                const row = Users{
                    .id = @intCast(i),
                    .name = "test",
                };
                const erow = try ddb.Adapter.toElement(row, allocator);
                elements[i] = erow;
            }

            try table.appendMany(elements);
        }

        const end = std.time.nanoTimestamp();

        const total_ns: i128 = end - start;
        const avg_ns: i128 = @divTrunc(total_ns, n);

        const total_ms: f64 = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms)) / 1000;
        const avg_us: f64 = @as(f64, @floatFromInt(avg_ns)) / @as(f64, @floatFromInt(std.time.ns_per_us)) / 1000;

        const total_insert: usize = n / 1000;

        std.debug.print(
            "{d}k insert ops: {d:.3} ms total, {d:.2} us per op\n",
            .{ total_insert, total_ms, avg_us },
        );
    }
}
