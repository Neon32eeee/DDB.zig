# DDB
## About

DDB is a library providing a basic set of tools for managing a database.

Requirements:
- Zig version: `0.15.1`
- OS:
  - Linux
  - macOS

Example:
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
    try Tplayers.append(ep);    

    try db.save();
}
```

## Installation

main branch
```
zig fetch --save https://github.com/Neon32eeee/DDB.zig/archive/refs/heads/main.tar.gz
```

build.zig:

```zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "myproject",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const ddb = b.dependency("ddb", .{
        .target = target,
        .optimize = optimize,
    });

    const ddb_module = b.createModule(.{
        .root_source_file = ddb.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe.root_module.addImport("ddb", ddb_module);
    b.installArtifact(exe);
}
```

## Coomand

1. Run main
```
zig build run
```

2. Load DB
```
zig build load
```

### Benchmarks

   1. Insert
   ```
   zig build insert_benchmark -Doptimize=ReleaseFast
   ```

   2. Save
   ```
   zig build save_benchmark -Doptimize=ReleaseFast
   ```

   3. Load 
   ```
   zig build load_benchmark -Doptimize=ReleaseFast
   ```

## More

more details at [Wiki](https://github.com/Neon32eeee/DDB.zig/wiki)
