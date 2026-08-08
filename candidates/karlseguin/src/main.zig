const std = @import("std");
const zqlite = @import("zqlite");

fn dbPath(allocator: std.mem.Allocator) ![:0]const u8 {
    if (std.c.getenv("ZIG_SQLITE_COMPARE_DB")) |p| {
        return try allocator.dupeZ(u8, std.mem.sliceTo(p, 0));
    }
    return try allocator.dupeZ(u8, "../../../fixtures/sample.db");
}

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    const path = try dbPath(allocator);
    defer allocator.free(path);

    const flags = zqlite.OpenFlags.ReadOnly | zqlite.OpenFlags.EXResCode;
    var conn = try zqlite.open(path.ptr, flags);
    defer conn.close();

    var rows = try conn.rows("SELECT id, slug, title FROM session LIMIT 5", .{});
    defer rows.deinit();
    while (rows.next()) |row| {
        std.debug.print("session: id={s} slug={s} title={s}\n", .{
            row.text(0),
            row.text(1),
            row.text(2),
        });
    }
    if (rows.err) |err| return err;

    if (try conn.row("SELECT count(*) FROM project", .{})) |row| {
        defer row.deinit();
        std.debug.print("project count: {d}\n", .{row.int(0)});
    }
}