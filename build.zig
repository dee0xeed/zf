const std = @import("std");

pub fn build(b: *std.Build) void {

//    const target = b.standardTargetOptions(.{});
//    const mode = b.standardReleaseOptions();
//    const exe = b.addExecutable("zf", "src/main.zig");
//    exe.single_threaded = true;
//    exe.setTarget(target);
//    exe.setBuildMode(mode);
//    exe.install();

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "zf",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .single_threaded = true,
        .strip = true,
    });

    b.installArtifact(exe);
}
