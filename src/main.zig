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

    const player1 = Player{ .hp = 100, .name = "Jon", .score = 100 };
    const player2 = Player{ .hp = 42, .name = "Len", .score = 110 };

    const Ep1 = try ddb.Adapter.toElement(player1, allocator);
    const Ep2 = try ddb.Adapter.toElement(player2, allocator);

    try db.createTable("players", Player);

    const Tplayers = db.getTable("players").?;

    try Tplayers.appendMany(&.{ Ep1, Ep2 });

    try db.save();
}
