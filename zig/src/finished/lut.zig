const std = @import("std");
const utils = @import("utils.zig");

const print = std.debug.print;

// TODO: this is the experimental change
// 0.1 increment -> comptime is faster, fits in the L1 cache
// 0.01 increment -> runtime is faster, does not fit in the L1 cache
const increment: comptime_float = 2;
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
        const val = @abs(@mod(prng.random().int(i64), steps));

        try file_writer.interface.print("{d}\n", .{val});

        // std.debug.print("{d},", .{val});
    }
}

pub fn main(init: std.process.Init) !void {
    _ = try generateTestCases(init.io, "lookup.txt");
    const test_cases = try utils.readArrayFromFile(TEST_SIZE, i64, init.io, "lookup.txt");

    const myLut = comptime generateLUT();

    var sum_comp: f64 = 0;

    const io = init.io;

    var start_time = std.Io.Clock.now(.awake, io);

    for (test_cases) |num| {
        //for (0..TEST_SIZE) |num| {
        // std.debug.print("input: {}, output: {}\n", .{ num, myLut[@intCast(num)] });
        sum_comp += myLut[@intCast(num)];
    }

    var end_time = std.Io.Clock.now(.awake, io);
    const duration_comp = start_time.durationTo(end_time);

    var sum_run: f64 = 0;

    start_time = std.Io.Clock.now(.awake, io);

    // dynamic
    for (test_cases) |num| {
        // for (0..TEST_SIZE) |num| {
        const float_num = @as(f64, @floatFromInt(num));
        const angle = float_num * @as(f64, increment);

        sum_run += @sin(angle) + @cos(angle);
    }

    end_time = std.Io.Clock.now(.awake, io);
    const duration_run = start_time.durationTo(end_time);
    std.debug.print("Runtime processed in: {} ns\n", .{duration_run.toNanoseconds()});
    std.debug.print("Comptime processed in: {} ns\n", .{duration_comp.toNanoseconds()});
    print("Sum comp: {d}\n", .{sum_comp});
    print("Sum run: {d}\n", .{sum_run});
}
