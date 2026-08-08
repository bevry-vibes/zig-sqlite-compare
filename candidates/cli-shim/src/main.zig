const std = @import("std");

const Query1 = "SELECT id, slug, title FROM session LIMIT 5;";
const Query2 = "SELECT count(*) FROM project;";

fn dbPath(allocator: std.mem.Allocator, env: *std.process.Environ.Map) ![]u8 {
    if (env.get("ZIG_SQLITE_COMPARE_DB")) |override| {
        return try allocator.dupe(u8, override);
    }
    return try allocator.dupe(u8, "../../../fixtures/sample.db");
}

fn runQuery(allocator: std.mem.Allocator, io: std.Io, db_path: []const u8, query: []const u8) ![]u8 {
    const argv = [_][]const u8{ "sqlite3", "-readonly", db_path, query };
    var child = try std.process.spawn(io, .{
        .argv = &argv,
        .stdout = .pipe,
        .stderr = .inherit,
    });
    var buf: [4096]u8 = undefined;
    var list: std.ArrayList(u8) = .empty;
    defer list.deinit(allocator);
    while (true) {
        const n = child.stdout.?.readStreaming(io, &.{&buf}) catch |e| switch (e) {
            error.EndOfStream => break,
            else => return e,
        };
        if (n == 0) break;
        try list.appendSlice(allocator, buf[0..n]);
    }
    _ = try child.wait(io);
    return try list.toOwnedSlice(allocator);
}

pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;
    const path = try dbPath(allocator, init.environ_map);
    defer allocator.free(path);

    const out1 = try runQuery(allocator, io, path, Query1);
    defer allocator.free(out1);
    std.debug.print("{s}", .{out1});

    const out2 = try runQuery(allocator, io, path, Query2);
    defer allocator.free(out2);
    std.debug.print("projects={s}", .{out2});
}