const std = @import("std");
const print = std.debug.print;
const utils = @import("utils.zig");

const PR_TASK_PERF_EVENTS_ENABLE: usize = 32;
const PR_TASK_PERF_EVENTS_DISABLE: usize = 33;

// TODO: this is the experimental change
// 1 increment -> must still test
// 0.1 increment -> comptime is faster, fits in the L1 cache
// 0.01 increment -> runtime is faster, does not fit in the L1 cache
const increment: comptime_float = 0.01;
const TEST_SIZE: usize = 500;
const degrees: comptime_float = 360;
const steps: comptime_int = @intFromFloat(degrees / increment);

pub fn main(init: std.process.Init) !void {
    const test_cases: [TEST_SIZE]i64 = try utils.readArrayFromFile(TEST_SIZE, init.io, "lookup.txt");

    print("LUT size: {d}, increment: {d}, testSize: {d}, degrees: {d}, steps: {d}\n", .{ steps, increment, TEST_SIZE, degrees, steps });

    const io = init.io;

    var sum: f64 = 0;

    _ = std.os.linux.prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    const start_time = std.Io.Clock.now(.awake, io);

    // dynamic
    for (test_cases) |num| {
        const float_num = @as(f64, @floatFromInt(num));

        // no need to offset here, we just use the test case as is
        sum += @sin(float_num) + @cos(float_num);
    }

    const end_time = std.Io.Clock.now(.awake, io);
    _ = std.os.linux.prctl(PR_TASK_PERF_EVENTS_DISABLE, 0, 0, 0, 0);

    const duration_run = start_time.durationTo(end_time);

    print("Runtime processed in: {} ns\n", .{duration_run.toNanoseconds()});
    print("Sum run: {d}\n", .{sum});
}
