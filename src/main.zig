const std = @import("std");
const ddb = @import("root.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    var db = try ddb.DB().init("DB", allocator);
    defer db.deinit();

    const Player = struct {
        hp: i32,
        name: []const u8,
        score: i32,
    };

    const Mob = struct {
        hp: i32,
        atk: f64,
    };

    const player1 = Player{ .hp = 100, .name = "Jon", .score = 100 };
    const player2 = Player{ .hp = 42, .name = "Len", .score = 110 };

    const mob1 = Mob{ .hp = 67, .atk = 6.7 };
    const mob2 = Mob{ .hp = 50, .atk = 10.4 };

    const Ep1 = try ddb.Adapter.toElement(player1, allocator);
    const Ep2 = try ddb.Adapter.toElement(player2, allocator);
    const Em1 = try ddb.Adapter.toElement(mob1, allocator);
    const Em2 = try ddb.Adapter.toElement(mob2, allocator);

    try db.createTable("players", Player);
    try db.createTable("mobs", Mob);

    const Tplayers = db.getTable("players").?;
    const Tmobs = db.getTable("mobs").?;

    try Tplayers.appendMany(&.{ Ep1, Ep2 });
    try Tmobs.appendMany(&.{ Em1, Em2 });

    try db.save();
}
