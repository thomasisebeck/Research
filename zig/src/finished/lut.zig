const std = @import("std");

const print = std.debug.print;

// TODO: this is the experimental change
const increment: comptime_float = 0.1;

// 0.1 increment -> comptime is faster, fits in the L1 cache
// 0.01 increment -> runtime is faster, does not fit in the L1 cache

const TEST_SIZE: usize = 1000;
const degrees: comptime_float = 360;
const steps: comptime_int = @intFromFloat(degrees / increment);

fn generateLUT() [steps]f64 {
    @setEvalBranchQuota(1000000);
    // table empty, but enough to hold all the sceps
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

fn generateTestCases() [TEST_SIZE]f64 {
    var table: [TEST_SIZE]f64 = undefined;

    var prng = std.Random.DefaultPrng.init(12345);

    for (0..TEST_SIZE) |ind| {
        // Map the random integer into a float: 0.0, 0.1... 359.9, 360.0
        const val = prng.random().float(f64) * 360.0;
        table[ind] = roundToIncrement(val, increment);
    }
    return table;
}

pub fn main(init: std.process.Init) void {
    const io = init.io;

    print("steps: {d}\n", .{steps});

    const toLookUp = generateTestCases();

    const myLut = comptime generateLUT();

    var sum: f64 = 0;

    var start_time = std.Io.Clock.now(.awake, io);

    // static
    for (toLookUp) |num| {
        const index: usize = @intFromFloat(std.math.round(num / increment));
        sum += myLut[index];
    }

    var end_time = std.Io.Clock.now(.awake, io);
    var duration = start_time.durationTo(end_time);
    std.debug.print("Comptime processed in: {} ns\n", .{duration.toNanoseconds()});
    print("Sum: {d}\n", .{sum});

    sum = 0;

    start_time = std.Io.Clock.now(.awake, io);

    // dynamic
    for (toLookUp) |num| {
        sum += @sin(num) + @cos(num);
    }

    end_time = std.Io.Clock.now(.awake, io);
    duration = start_time.durationTo(end_time);
    std.debug.print("Runtime processed in: {} ns\n", .{duration.toNanoseconds()});
    print("Sum: {d}\n", .{sum});
}
