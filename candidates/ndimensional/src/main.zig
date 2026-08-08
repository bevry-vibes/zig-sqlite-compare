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

    const db = try sqlite.Database.open(.{
        .path = path,
        .mode = .ReadOnly,
    });
    defer db.close();

    const SessionRow = struct {
        id: sqlite.Text,
        slug: sqlite.Text,
        title: sqlite.Text,
    };
    var session_stmt = try db.prepare(struct {}, SessionRow,
        "SELECT id, slug, title FROM session LIMIT 5");
    defer session_stmt.finalize();
    try session_stmt.bind(.{});
    defer session_stmt.reset();

    while (try session_stmt.step()) |row| {
        std.debug.print("id={s} slug={s} title={s}\n", .{ row.id.data, row.slug.data, row.title.data });
    }

    const CountRow = struct { count: i64 };
    var count_stmt = try db.prepare(struct {}, CountRow,
        "SELECT count(*) AS count FROM project");
    defer count_stmt.finalize();
    try count_stmt.bind(.{});
    defer count_stmt.reset();

    if (try count_stmt.step()) |row| {
        std.debug.print("projects={d}\n", .{row.count});
    }
}