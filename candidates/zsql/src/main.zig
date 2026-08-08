const std = @import("std");
const zsql = @import("zsql");

const SqliteDriver = zsql.drivers.sqlite.Driver;
const Database = zsql.Database(SqliteDriver);

fn dbPath(allocator: std.mem.Allocator) ![]u8 {
    if (std.c.getenv("ZIG_SQLITE_COMPARE_DB")) |override| {
        return try allocator.dupe(u8, std.mem.sliceTo(override, 0));
    }
    return try allocator.dupe(u8, "../../../fixtures/sample.db");
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const path = try dbPath(allocator);
    defer allocator.free(path);

    var db = try Database.open(allocator, .{ .path = path });
    defer db.deinit();
    var conn = try db.connect();
    defer conn.close();

    // Use execScript for non-SELECT path (avoids lib's broken SELECT bind path).
    try conn.execScript("INSERT INTO project VALUES ('__measure_test__', 'x', 'y', 0);");
    try conn.execScript("DELETE FROM project WHERE id = '__measure_test__';");
}