const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const exe = b.addExecutable(.{
        .name = "injector",
        .root_module = exe_mod,
    });

    // Win32
    {
        exe.linkSystemLibrary("user32");
        exe.linkSystemLibrary("kernel32");

        const win32 = b.dependency("zigwin32", .{});
        exe.root_module.addImport("win32", win32.module("win32"));
    }

    b.installArtifact(exe);

    // Run runs the injector
    {
        const run_cmd = b.addRunArtifact(exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| {
            run_cmd.addArgs(args);
        }

        const run_step = b.step("run", "Run the app");
        run_step.dependOn(&run_cmd.step);
    }
}
