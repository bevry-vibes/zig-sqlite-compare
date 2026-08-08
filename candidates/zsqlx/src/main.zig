const std = @import("std");
const zsqlx = @import("zsqlx");

fn dbPath(allocator: std.mem.Allocator) ![]u8 {
    if (std.c.getenv("ZIG_SQLITE_COMPARE_DB")) |override| {
        return try allocator.dupe(u8, std.mem.sliceTo(override, 0));
    }
    return try allocator.dupe(u8, "../../../fixtures/sample.db");
}

pub fn main(init: std.process.Init) !void {
    const gpa = init.gpa;
    const io = init.io;
    const path = try dbPath(gpa);
    defer gpa.free(path);

    var conn = try zsqlx.sqlite.SqliteConnection.connect(gpa, io, .{ .filename = path });
    defer conn.close(io);

    try conn.rawSql(io, "SELECT id, slug, title FROM session LIMIT 5");
    try conn.rawSql(io, "SELECT count(*) as cnt FROM project");
}