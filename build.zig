const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const mod = b.addModule("DDB", .{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const lib = b.addLibrary(.{
        .name = "ddb",
        .linkage = .static,
        .root_module = mod,
    });

    const default_step = b.step("default", "Build library");
    default_step.dependOn(&lib.step);

    const exe = b.addExecutable(.{
        .name = "DDB",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ddb", .module = mod },
            },
        }),
    });

    const run_step = b.step("run", "Run the app");
    const run_cmd = b.addRunArtifact(exe);

    const benchmark = b.addExecutable(.{
        .name = "benchmark",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/benchmark.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ddb", .module = mod },
            },
        }),
    });

    const benchmark_step = b.step("benchmark", "benchmark the app");
    const benchmark_cmd = b.addRunArtifact(benchmark);

    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());
    benchmark_step.dependOn(&benchmark_cmd.step);
    benchmark_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const mod_tests = b.addTest(.{ .root_module = mod });
    const run_mod_tests = b.addRunArtifact(mod_tests);

    const exe_tests = b.addTest(.{ .root_module = exe.root_module });
    const run_exe_tests = b.addRunArtifact(exe_tests);

    b.installArtifact(lib);

    const test_step = b.step("test", "Run tests");
    test_step.dependOn(&run_mod_tests.step);
    test_step.dependOn(&run_exe_tests.step);
}
