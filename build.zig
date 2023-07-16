const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "gpulse",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a RunStep in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

    const coverage_exe = b.addExecutable(.{
        .name = "gpulse_coverage",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/coverage.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(coverage_exe);
    const coverage_cmd = b.addRunArtifact(coverage_exe);
    coverage_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        coverage_cmd.addArgs(args);
    }
    const coverage_step = b.step("coverage", "Run parser/analyzer coverage suite.");
    coverage_step.dependOn(&coverage_cmd.step);

    // Fuzzing
    const fuzz_exe = b.addExecutable(.{
        .name = "gpulse_fuzz",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/fuzz.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(fuzz_exe);
    const fuzz_cmd = b.addRunArtifact(fuzz_exe);
    fuzz_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        fuzz_cmd.addArgs(args);
    }
    const fuzz_step = b.step("fuzz", "Fuzz parser.");
    fuzz_step.dependOn(&fuzz_cmd.step);

    // Formatting
    const fmt_exe = b.addExecutable(.{
        .name = "gpulse_fmt",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/fmt.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(fmt_exe);
    const fmt_cmd = b.addRunArtifact(fmt_exe);
    fmt_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        fmt_cmd.addArgs(args);
    }
    const fmt_step = b.step("fmt", "Format source.wgsl.");
    fmt_step.dependOn(&fmt_cmd.step);

    // Formatting
    const lsp_exe = b.addExecutable(.{
        .name = "gpulse_lsp",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/lsp/Server.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(lsp_exe);
    const lsp_cmd = b.addRunArtifact(lsp_exe);
    lsp_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        lsp_cmd.addArgs(args);
    }
    const lsp_step = b.step("lsp", "Language server.");
    lsp_step.dependOn(&lsp_cmd.step);
}
