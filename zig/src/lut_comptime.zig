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

fn generateLUT() [steps]f64 {
    @setEvalBranchQuota(1000000);
    // table empty, but enough to hold all the steps
    var table: [steps]f64 = undefined;

    for (&table, 0..) |*item, i| {
        const result: f64 = @as(f64, @floatFromInt(i)) * increment;
        item.* = @sin(result) + @cos(result);
    }

    return table;
}

pub fn roundToIncrement(value: f64, inc: f64) f64 {
    const multiplier = 1.0 / inc;
    return std.math.round(value * multiplier) / multiplier;
}

fn generateTestCases(io: anytype, path: []const u8) !void {
    var file = try std.Io.Dir.cwd().createFile(io, path, .{ .truncate = true });
    defer file.close(io);

    var file_writer = file.writer(io, &.{});

    var prng = std.Random.DefaultPrng.init(12345);

    for (0..TEST_SIZE) |_| {
        // steps is the max index that you can access in the LUT
        // just store a random index to look up
        const val = @abs(@mod(prng.random().int(i64), @as(i64, degrees)));

        try file_writer.interface.print("{d}\n", .{val});

        // std.debug.print("{d},", .{val});
    }
}

pub fn main(init: std.process.Init) !void {
    _ = try generateTestCases(init.io, "lookup.txt");
    const test_cases: [TEST_SIZE]i64 = try utils.readArrayFromFile(TEST_SIZE, init.io, "lookup.txt");

    var myLut = comptime generateLUT();

    print("LUT size: {d}, increment: {d}, testSize: {d}, degrees: {d}, steps: {d}\n", .{ steps, increment, TEST_SIZE, degrees, steps });

    var sum_comp: f64 = 0;

    const io = init.io;

    _ = std.os.linux.prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    var start_time = std.Io.Clock.now(.awake, io);

    // test cases is i64 arr
    // num / increment, making it larger (if inc between 0 and 1)
    for (test_cases) |num| {
        const float_idx = @as(f64, @floatFromInt(num)) / increment;

        sum_comp += myLut[@intFromFloat(float_idx)];
    }

    const end_time = std.Io.Clock.now(.awake, io);
    _ = std.os.linux.prctl(PR_TASK_PERF_EVENTS_DISABLE, 0, 0, 0, 0);

    const duration_comp = start_time.durationTo(end_time);

    // WARN: dummy mutation to allow us to allocate on the stack
    myLut[0] += @as(f64, @floatFromInt(test_cases[0]));

    print("Comptime processed in: {} ns\n", .{duration_comp.toNanoseconds()});
    print("Sum comp: {d}\n", .{sum_comp});
}
