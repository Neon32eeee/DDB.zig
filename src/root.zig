const std = @import("std");
pub const Table = @import("Table.zig");
const Types = @import("Types.zig");
pub const Adapter = @import("ElementAdapter.zig");
pub const Element = Types.Element;

pub fn DB() type {
    return struct {
        path: []const u8,
        tables: std.StringHashMap(Table.Table),
        allocator: std.mem.Allocator,
        io: std.Io,
        metadata_buffer: ?[]u8 = null,

        pub fn init(name_file: []const u8, allocator: std.mem.Allocator, io: std.Io) !@This() {
            return @This(){
                .path = name_file,
                .tables = std.StringHashMap(Table.Table).init(allocator),
                .allocator = allocator,
                .io = io,
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
            if (db.tables.contains(name)) return;

            var scheme = std.ArrayList([]const u8).empty;
            const info = @typeInfo(T);

            inline for (info.@"struct".fields) |field| {
                const fname = field.name;

                try scheme.append(db.allocator, fname);
            }

            const table = Table.Table.init(@typeName(T), db.allocator, scheme);

            try db.tables.put(name, table);
        }

        pub fn dropTable(db: *@This(), name: []const u8) !void {
            var targetTable = db.tables.get(name) orelse return error.TableNotFound;
            if (!db.tables.remove(name)) return error.ErrorRemoveTable;
            targetTable.deinit();
        }

        pub fn getTable(db: @This(), name: []const u8) ?*Table.Table {
            return db.tables.getPtr(name) orelse null;
        }

        pub fn iterator(db: *@This()) Types.DBIterator {
            return Types.DBIterator{
                .it = db.tables.iterator(),
            };
        }

        pub fn save(db: @This()) !void {
            const ftmpname = try std.mem.concat(db.allocator, u8, &.{ db.path, ".tmp" });
            defer db.allocator.free(ftmpname);

            var file = try std.Io.Dir.cwd().createFile(db.io, ftmpname, .{});
            defer file.close(db.io);

            const buff = try db.allocator.alloc(u8, 128);
            defer db.allocator.free(buff);

            var writer = file.writer(db.io, buff);
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
                try w.writeInt(usize, v.mainScheme.items.len, .little);
                for (v.mainScheme.items) |i| {
                    try w.writeInt(usize, i.len, .little);
                    try w.writeAll(i);
                }
            }
            try w.flush();

            try file.sync(db.io);
            try std.Io.Dir.cwd().rename(ftmpname, std.Io.Dir.cwd(), db.path, db.io);

            const tdir_name = try std.mem.concat(db.allocator, u8, &[_][]const u8{ db.path, "dir" });
            defer db.allocator.free(tdir_name);

            std.Io.Dir.cwd().createDir(db.io, tdir_name, .default_dir) catch |err| {
                if (err != std.Io.Dir.CreateDirError.PathAlreadyExists) return err;
            };
            var tdir = try std.Io.Dir.cwd().openDir(db.io, tdir_name, .{});
            defer tdir.close(db.io);

            var group = std.Io.Group.init;

            it = db.tables.iterator();

            while (it.next()) |e| {
                const k = e.key_ptr.*;
                const v = e.value_ptr;

                group.async(db.io, saveTableTask, .{
                    db.allocator,
                    tdir_name,
                    k,
                    v.rows.items,
                    db.io,
                });
            }

            try group.await(db.io);
        }

        fn saveTableTask(
            allocator: std.mem.Allocator,
            tdir_name: []const u8,
            table_name: []const u8,
            rows: []const Element,
            io: std.Io,
        ) void {
            const tmpname = std.mem.concat(allocator, u8, &.{ table_name, ".tmp" }) catch return;
            defer allocator.free(tmpname);

            var tdir = std.Io.Dir.cwd().openDir(io, tdir_name, .{}) catch return;
            defer tdir.close(io);

            var table_file = tdir.createFile(io, tmpname, .{}) catch return;
            defer table_file.close(io);

            const tbuff = allocator.alloc(u8, 128) catch return;
            defer allocator.free(tbuff);

            var twriter = table_file.writer(io, tbuff);
            var tw = &twriter.interface;

            for (rows) |elem| {
                elem.save(&twriter) catch return;
            }

            tw.flush() catch {};

            table_file.sync(io) catch return;
            tdir.rename(tmpname, tdir, table_name, io) catch return;
        }

        pub fn load(db: *@This()) !void {
            var file = std.Io.Dir.cwd().openFile(db.io, db.path, .{}) catch |err| {
                if (err == error.FileNotFound) return;
                return err;
            };
            defer file.close(db.io);

            const stat = try file.stat(db.io);
            const size = stat.size;

            const buff = try db.allocator.alloc(u8, @intCast(size));
            db.metadata_buffer = buff;

            var reader = file.reader(db.io, buff);
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

                var scheme = std.ArrayList([]const u8).empty;
                errdefer scheme.deinit(db.allocator);

                const schemeLen = try r.takeInt(usize, .little);
                for (0..schemeLen) |_| {
                    const fieldNameLen = try r.takeInt(usize, .little);
                    const fieldName = try r.take(fieldNameLen);
                    try scheme.append(db.allocator, fieldName);
                }

                var table = Table.Table.init(tname, db.allocator, scheme);

                const tdir_name = try std.mem.concat(db.allocator, u8, &[_][]const u8{ db.path, "dir" });
                defer db.allocator.free(tdir_name);

                std.Io.Dir.cwd().createDir(db.io, tdir_name, .default_dir) catch |err| {
                    if (err != std.Io.Dir.CreateDirError.PathAlreadyExists) return err;
                };
                var tdir = try std.Io.Dir.cwd().openDir(db.io, tdir_name, .{});
                defer tdir.close(db.io);

                var tfile = tdir.openFile(db.io, k, .{}) catch |err| {
                    if (err == error.FileNotFound) continue;
                    return err;
                };
                defer tfile.close(db.io);

                const tstat = try tfile.stat(db.io);
                const tsize = tstat.size;

                var tbuff = try db.allocator.alloc(u8, @intCast(tsize));
                table.data_buffer = tbuff;

                var treader = tfile.reader(db.io, tbuff[0..]);

                var elements = try db.allocator.alloc(Element, count_row);
                defer db.allocator.free(elements);

                for (0..count_row) |i| {
                    var element = Element{
                        .field = std.StringHashMap(Types.FieldType).init(db.allocator),
                        .tname = tname,
                        .scheme = &table.mainScheme,
                        .allocator = db.allocator,
                    };

                    try element.load(db.allocator, &treader);

                    elements[i] = element;
                }

                try table.appendMany(elements);

                try db.tables.put(k, table);
            }
        }
    };
}

test "Init Db" {
    const alloc = std.heap.page_allocator;
    const io = std.testing.io;
    var db = try DB().init("DB.db", alloc, io);
    defer db.deinit();
}

test "Create Table" {
    const alloc = std.heap.page_allocator;
    const io = std.testing.io;
    var db = try DB().init("DB.db", alloc, io);
    defer db.deinit();

    const Users = struct {
        id: i32,
        name: []const u8,
    };

    try db.createTable("users", Users);
}

test "Drop Table" {
    const alloc = std.heap.page_allocator;
    const io = std.testing.io;
    var db = try DB().init("DB.db", alloc, io);
    defer db.deinit();

    const Users = struct {
        id: i32,
        name: []const u8,
    };

    try db.createTable("users", Users);
    try db.dropTable("users");
}

test "Get Table" {
    const alloc = std.testing.allocator;
    const io = std.testing.io;
    var db = try DB().init("DB.db", alloc, io);
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
    const io = std.testing.io;
    var db = try DB().init("DB.db", alloc, io);
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

    try Tuser.appendMany(&.{ Euser, Euser2 });
    try db.save();
}

test "Load DB" {
    const alloc = std.heap.page_allocator;
    const io = std.testing.io;
    var db = try DB().init("DB.db", alloc, io);
    defer db.deinit();

    try db.load();

    const Tusers = db.getTable("users").?;

    const Eusers = Tusers.get(0).?;
    const Eusers2 = Tusers.get(1).?;

    std.debug.print("\n{s}, {s}\n", .{ Eusers.getAs([]const u8, "name").?, Eusers2.getAs([]const u8, "name").? });
}

test "Iterator DB" {
    const alloc = std.testing.allocator;
    const io = std.testing.io;
    var db = try DB().init("DB.db", alloc, io);
    defer db.deinit();

    const Users = struct {
        id: i32,
        name: []const u8,
    };

    const Item = struct {
        name: []const u8,
    };

    try db.createTable("users", Users);
    try db.createTable("items", Item);

    var it = db.iterator();

    while (it.next()) |t| {
        std.debug.print("\n{s}", .{t.*.tname});
    }
}
