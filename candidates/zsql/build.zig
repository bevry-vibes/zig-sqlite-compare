const std = @import("std");

const targets = [_]struct { name: []const u8, query: std.Target.Query }{
    .{ .name = "linux-x86_64", .query = .{ .cpu_arch = .x86_64, .os_tag = .linux, .abi = .musl } },
    .{ .name = "linux-aarch64", .query = .{ .cpu_arch = .aarch64, .os_tag = .linux, .abi = .musl } },
    .{ .name = "macos-aarch64", .query = .{ .cpu_arch = .aarch64, .os_tag = .macos } },
    .{ .name = "windows-x86_64", .query = .{ .cpu_arch = .x86_64, .os_tag = .windows, .abi = .gnu } },
};

pub fn build(b: *std.Build) void {
    for (targets) |t| {
        const target = b.resolveTargetQuery(t.query);
        const optimize = .ReleaseSmall;

        const dep = b.dependency("zsql", .{
            .target = target,
            .optimize = optimize,
            .@"enable-sqlite" = true,
        });

        const root_mod = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .strip = true,
            .link_libc = true,
        });
        root_mod.addImport("zsql", dep.module("zsql"));

        const exe = b.addExecutable(.{
            .name = b.fmt("zsql-{s}", .{t.name}),
            .root_module = root_mod,
        });
        b.installArtifact(exe);
    }
}