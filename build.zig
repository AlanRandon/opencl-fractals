const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const spirv_target = b.resolveTargetQuery(std.Target.Query{
        .cpu_arch = .spirv64,
        .abi = .gnu,
        .ofmt = .spirv,
        .os_tag = .opencl,
        .cpu_features_add = std.Target.spirv.featureSet(&.{
            .int64,
            .int16,
            .int8,
            .float64,
            .float16,
            .vector16,
        }),
    });

    const kernels_mod = b.createModule(.{
        .root_source_file = b.path("src/kernels.zig"),
        .target = spirv_target,
        .optimize = optimize,
    });

    const kernels_lib = b.addLibrary(.{
        .name = "kernels",
        .root_module = kernels_mod,
    });

    b.installArtifact(kernels_lib);

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    exe_mod.linkSystemLibrary("OpenCL", .{});
    exe_mod.addCSourceFile(.{ .file = b.path("src/stb_impl.c") });

    exe_mod.addAnonymousImport("kernels.spv", .{
        .root_source_file = kernels_lib.getEmittedBin(),
    });

    const exe = b.addExecutable(.{
        .name = "opencl_test",
        .root_module = exe_mod,
    });

    exe.linkLibC();

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_module = exe_mod,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
