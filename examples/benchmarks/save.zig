const std = @import("std");
const ddb = @import("ddb");

pub fn main(init: std.process.Init) !void {
    var gpa = std.heap.DebugAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const io = init.io;

    // init db
    var db = try ddb.DB().init("save.db", allocator, io);
    defer db.deinit();

    const Users = struct {
        id: i32,
        name: []const u8,
    };
    try db.createTable("users", Users);

    var table = db.getTable("users").?;

    var increase: usize = 1;
    inline for (0..3) |_| {
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

        const start = std.Io.Clock.awake.now(io);

        for (0..1000) |_| {
            try db.save();
        }

        const total_ns = start.untilNow(io, .awake).toNanoseconds();
        const avg_ns: i128 = @divTrunc(total_ns, n);

        const total_sec: f64 = @as(f64, @floatFromInt(total_ns)) / @as(f64, @floatFromInt(std.time.ns_per_s)) / 1000;
        const avg_sec: f64 = @as(f64, @floatFromInt(avg_ns)) / @as(f64, @floatFromInt(std.time.ns_per_us)) / 1000;

        const file_info = try std.Io.Dir.cwd().statFile(io, "save.dbdir/users", .{});

        const size_bytes = file_info.size;
        const size_kb = @as(f64, @floatFromInt(size_bytes)) / 1024.0;

        const totsal_insert: usize = n / 1000;

        std.debug.print(
            "{d}k element save ops: {d:.3} s total, {d:.2} us per op\nTotal size file: {d:.2} Kb\n",
            .{ totsal_insert, total_sec, avg_sec, size_kb },
        );

        table.clear();
    }
}
