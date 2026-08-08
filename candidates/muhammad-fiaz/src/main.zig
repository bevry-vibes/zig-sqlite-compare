const std = @import("std");
const sqlite = @import("sqlite");

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

    var db = try sqlite.open(allocator, path);
    defer db.close();

    var result = try db.exec("SELECT id, slug, title FROM session LIMIT 5;");
    defer result.deinit();

    for (result.rows) |row| {
        std.debug.print("id={s} slug={s} title={s}\n", .{ row[0].text, row[1].text, row[2].text });
    }

    var result2 = try db.exec("SELECT count(*) as cnt FROM project;");
    defer result2.deinit();
    if (result2.rows.len > 0) {
        std.debug.print("projects={d}\n", .{result2.rows[0][0].integer});
    }
}