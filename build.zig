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

    const insert = b.addExecutable(.{
        .name = "insert_benchmark",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/benchmarks/insert.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ddb", .module = mod },
            },
        }),
    });

    const insert_step = b.step("insert_benchmark", "insert the DB");
    const insert_cmd = b.addRunArtifact(insert);

    const load = b.addExecutable(.{
        .name = "load",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/load.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ddb", .module = mod },
            },
        }),
    });

    const load_step = b.step("load", "load on DB");
    const load_cmd = b.addRunArtifact(load);

    const save_benchmark = b.addExecutable(.{
        .name = "save_benchmark",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/benchmarks/save.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ddb", .module = mod },
            },
        }),
    });

    const save_step = b.step("save_benchmark", "save benchmark the DB");
    const save_cmd = b.addRunArtifact(save_benchmark);

    const load_benchmark = b.addExecutable(.{
        .name = "load_benchmark",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/benchmarks/load.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "ddb", .module = mod },
            },
        }),
    });

    const load_benchmark_step = b.step("load_benchmark", "load benchmark the DB");
    const load_benchmark_cmd = b.addRunArtifact(load_benchmark);

    run_step.dependOn(&run_cmd.step);
    run_cmd.step.dependOn(b.getInstallStep());

    insert_step.dependOn(&insert_cmd.step);
    insert_cmd.step.dependOn(b.getInstallStep());

    load_step.dependOn(&load_cmd.step);
    load_cmd.step.dependOn(b.getInstallStep());

    save_step.dependOn(&save_cmd.step);
    save_cmd.step.dependOn(b.getInstallStep());

    load_benchmark_step.dependOn(&load_benchmark_cmd.step);
    load_benchmark_cmd.step.dependOn(b.getInstallStep());

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
