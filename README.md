# DDB
## О прэкте

DDB - это билиеотека предостовляюшея базовый набор для упровления Базой Данных.

Требывания:
- Версия zig: `0.15.1`
- ОС:
  - Linux
  - Mac Os
  
Пример:
```zig
const std = @import("std");
const ddb = @import("ddb");

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
    const ep = try ddb.Adapter.toElement(player1, allocator);

    try db.createTable("players", Player);

    const Tplayers = db.getTable("players").?;
    try Tplayers.append(Ep2);    

    try db.save();
}
```

## Установка

main ветка
```
zig fetch --save https://github.com/Neon32eeee/DDB.zig/archive/refs/heads/main.tar.gz
```

buld.zig:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addModule("myproject", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

+    const ddb = b.dependency("ddb", .{
+        .target = target,
+        .optimize = optimize,
+    });

+    const ddb_module = b.addModule("ddb", .{ .root_source_file = ddb.path("src/root.zig") });

    exe.root_module.addImport("ddb", ddb_module);

    b.installArtifact(exe);
}
```

