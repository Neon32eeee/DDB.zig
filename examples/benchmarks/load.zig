const std = @import("std");
const ddb = @import("ddb");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // init db
    var db = try ddb.DB().init("load.db", allocator);
    defer db.deinit();

    const Users = struct {
        id: i32,
        name: []const u8,
    };
    try db.createTable("users", Users);

    var table = db.getTable("users").?;

    var increase: usize = 1;
    inline for (0..3) |_| {
        table.clear();
        const n = 1000 * increase;
        increase += if (increase == 1) 9 else 90;

        var elements = try allocator.alloc(ddb.Element, n);
        defer allocator.free(elements);

        for (0..n) |i| {
            const row = Users{
                .id = @intCast(i),
                .name = "test",
            };
            const erow = try ddb.Adapter.toElement(row, allocator);
            elements[i] = erow;
        }

        try table.appendMany(elements);

        try db.save();

        var db_load = try ddb.DB().init("load.db", allocator);
        defer db_load.deinit();

        const start = std.time.nanoTimestamp();

        try db_load.load();

        const end = std.time.nanoTimestamp();

        const total_ns: i128 = end - start;

        const total_f64: f64 = @floatFromInt(total_ns);
        const n_f64: f64 = @floatFromInt(n);
        const avg_ns: f64 = total_f64 / n_f64;
        const total_us: f64 = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(std.time.ns_per_ms));

        const totsal_insert: usize = n / 1000;

        std.debug.print(
            "{d}k element load ops: {d:.3} ms total, {d:.2} ns per op\n",
            .{ totsal_insert, total_us, avg_ns },
        );
    }
}
