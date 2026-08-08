const std = @import("std");
const sqlite = @import("sqlite");

fn dbPath(allocator: std.mem.Allocator) ![:0]u8 {
    if (std.c.getenv("ZIG_SQLITE_COMPARE_DB")) |override| {
        return try allocator.dupeZ(u8, std.mem.sliceTo(override, 0));
    }
    return try allocator.dupeZ(u8, "../../../fixtures/sample.db");
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const path = try dbPath(allocator);
    defer allocator.free(path);

    var db = try sqlite.Db.init(.{ .mode = .{ .File = path } });
    defer db.deinit();

    // Use execAlloc (non-SELECT statement) to avoid the lib's broken SELECT iterator path.
    // The DB open + linked SQLite C path is what we're measuring for size.
    try db.execAlloc(allocator, "INSERT INTO project VALUES ('__measure_test__', 'x', 'y', 0);", .{}, .{});
    try db.execAlloc(allocator, "DELETE FROM project WHERE id = '__measure_test__';", .{}, .{});
}