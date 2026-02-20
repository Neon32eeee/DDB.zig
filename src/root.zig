const std = @import("std");
const Table = @import("Table.zig");
const Types = @import("Types.zig");
pub const Adapter = @import("ElementAdapter.zig");

pub fn DB() type {
    return struct {
        path: []const u8,
        tables: std.StringHashMap(Table.Table),
        allocator: std.mem.Allocator,
        metadata_buffer: ?[]u8 = null,

        pub fn init(name_file: []const u8, allocator: std.mem.Allocator) !@This() {
            return @This(){
                .path = name_file,
                .tables = std.StringHashMap(Table.Table).init(allocator),
                .allocator = allocator,
            };
        }

        pub fn deinit(db: *@This()) void {
            var it = db.tables.iterator();

            while (it.next()) |e| {
                var v = e.value_ptr.*;
                v.deinit();
            }
            db.tables.deinit();

            if (db.metadata_buffer) |b| db.allocator.free(b);
        }

        pub fn createTable(db: *@This(), name: []const u8, comptime T: type) !void {
            comptime {
                if (@typeInfo(T) != .@"struct") {
                    @compileError("Invalid type");
                }
            }

            const table = Table.Table.init(@typeName(T), db.allocator);

            if (!db.tables.contains(name)) {
                try db.tables.put(name, table);
            }
        }

        pub fn getTable(db: @This(), name: []const u8) ?*Table.Table {
            return db.tables.getPtr(name) orelse null;
        }

        pub fn save(db: @This()) !void {
            var file = try std.fs.cwd().createFile(db.path, .{});
            defer file.close();

            const buff = try db.allocator.alloc(u8, 8);
            defer db.allocator.free(buff);

            var writer = file.writer(buff);
            var w = &writer.interface;

            var it = db.tables.iterator();

            while (it.next()) |e| {
                const k = e.key_ptr.*;
                const v = e.value_ptr;

                try w.writeInt(u32, @intCast(k.len), .little);
                try w.writeAll(k);
                try w.writeInt(u32, @intCast(v.tname.len), .little);
                try w.writeAll(v.tname);
                try w.writeInt(usize, @intCast(v.rows.items.len), .little);

                const tdir_name = try std.mem.concat(db.allocator, u8, &[_][]const u8{ db.path, "dir" });
                defer db.allocator.free(tdir_name);

                var tdir = try std.fs.cwd().makeOpenPath(tdir_name, .{});
                defer tdir.close();

                var table_file = try tdir.createFile(k, .{});
                defer table_file.close();

                const tbuff = try db.allocator.alloc(u8, 8);
                defer db.allocator.free(tbuff);

                var twriter = table_file.writer(tbuff);
                var tw = &twriter.interface;

                for (v.rows.items) |elem| {
                    try elem.save(&twriter);
                }

                try tw.flush();
            }
            try w.flush();
        }

        pub fn load(db: *@This()) !void {
            var file = std.fs.cwd().openFile(db.path, .{}) catch |err| {
                if (err == error.FileNotFound) return;
                return err;
            };
            defer file.close();

            const stat = try file.stat();
            const size = stat.size;

            const buff = try db.allocator.alloc(u8, @intCast(size));
            db.metadata_buffer = buff;

            var reader = file.reader(buff);
            var r = &reader.interface;

            while (true) {
                const kl = r.takeInt(u32, .little) catch |err| {
                    if (err == error.EndOfStream) return;
                    return err;
                };

                const k = try r.take(@intCast(kl));

                const tnamel = try r.takeInt(u32, .little);

                const tname_u8: []u8 = try r.take(@intCast(tnamel));
                const tname: []const u8 = tname_u8;

                const count_row = try r.takeInt(usize, .little);

                var table = Table.Table.init(tname, db.allocator);

                const tdir_name = try std.mem.concat(db.allocator, u8, &[_][]const u8{ db.path, "dir" });
                defer db.allocator.free(tdir_name);

                var tdir = try std.fs.cwd().makeOpenPath(tdir_name, .{});
                defer tdir.close();

                var tfile = tdir.openFile(k, .{}) catch |err| {
                    if (err == error.FileNotFound) continue;
                    return err;
                };
                defer tfile.close();

                const tstat = try tfile.stat();
                const tsize = tstat.size;

                var tbuff = try db.allocator.alloc(u8, @intCast(tsize));
                table.data_buffer = tbuff;

                var treader = tfile.reader(tbuff[0..]);

                for (0..count_row) |_| {
                    var element = Types.Element{ .field = std.StringHashMap(Types.FieldType).init(db.allocator), .tname = tname };

                    try element.load(db.allocator, &treader);

                    try table.append(element);
                }

                try db.tables.put(k, table);
            }
        }
    };
}

test "Init Db" {
    const alloc = std.heap.page_allocator;
    var db = try DB().init("DB.db", alloc);
    defer db.deinit();
}

test "Create Table" {
    const alloc = std.heap.page_allocator;
    var db = try DB().init("DB.db", alloc);
    defer db.deinit();

    const Users = struct {
        id: i32,
        name: []const u8,
    };

    try db.createTable("users", Users);
}

test "Get Table" {
    const alloc = std.testing.allocator;
    var db = try DB().init("DB.db", alloc);
    defer db.deinit();

    const Users = struct {
        id: i32,
        name: []const u8,
    };

    try db.createTable("users", Users);

    const TableUsers = db.getTable("users");

    if (TableUsers == null) {
        return error.InvalidGetTable;
    }
}

test "Save DB" {
    const alloc = std.testing.allocator;
    var db = try DB().init("DB", alloc);
    defer db.deinit();

    const allocator = std.testing.allocator;

    const Users = struct {
        id: i32,
        name: []const u8,
    };

    try db.createTable("users", Users);

    var Tuser = db.getTable("users").?;

    const user = Users{ .id = 0, .name = "Jon" };
    const user2 = Users{ .id = 0, .name = "Len" };

    const Euser = try Adapter.toElement(user, allocator);
    const Euser2 = try Adapter.toElement(user2, allocator);

    try Tuser.append(Euser);
    try Tuser.append(Euser2);

    try db.save();
}

test "Load DB" {
    const alloc = std.heap.page_allocator;
    var db = try DB().init("DB", alloc);
    defer db.deinit();

    try db.load();

    const Tusers = db.getTable("users").?;

    const Eusers = Tusers.get(0).?;
    const Eusers2 = Tusers.get(1).?;

    std.debug.print("\n{s}, {s}\n", .{ Eusers.getAs([]const u8, "name").?, Eusers2.getAs([]const u8, "name").? });
}
