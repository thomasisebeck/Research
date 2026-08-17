const std = @import("std");

// Although this function looks imperative, it does not perform the build
// directly and instead it mutates the build graph (`b`) that will be then
// executed by an external runner. The functions in `std.Build` implement a DSL
// for defining build steps and express dependencies between them, allowing the
// build runner to parallelize the build automatically (and the cache system to
// know when a step doesn't need to be re-run).
pub fn build(b: *std.Build) void {
    // NOTE: select native arch
    const target = b.standardTargetOptions(.{
        .default_target = .{
            .cpu_model = .native,
        },
    });
    // NOTE: turn on optimisation
    const optimize = b.standardOptimizeOption(.{});

    const increment = b.option(f64, "increment", "LUT increment value") orelse 0.01;
    const target_src = b.option([]const u8, "target_src", "Source file to build") orelse "src/lut_runtime.zig";

    const options = b.addOptions();
    // Fix: Add the option so 'increment' is used!
    options.addOption(f64, "increment", increment);

    // INFO: change this source file
    const exe = b.addExecutable(.{
        .name = "out",
        .root_module = b.createModule(.{
            .root_source_file = b.path(target_src),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.addOptions("config", options);

    // This declares intent for the executable to be installed into the
    // install prefix when running `zig build` (i.e. when executing the default
    // step). By default the install prefix is `zig-out/` but can be overridden
    // by passing `--prefix` or `-p`.
    b.installArtifact(exe);

    // This creates a top level step. Top level steps have a name and can be
    // invoked by name when running `zig build` (e.g. `zig build run`).
    // This will evaluate the `run` step rather than the default step.
    // For a top level step to actually do something, it must depend on other
    // steps (e.g. a Run step, as we will see in a moment).
    const run_step = b.step("run", "Run the app");

    const run_cmd = b.addRunArtifact(exe);
    run_step.dependOn(&run_cmd.step);

    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }
}
