const std = @import("std");
const print = std.debug.print;
const assert = std.debug.assert;
const utils = @import("utls.zig");

const Point = struct { x: f64, y: f64 };

fn getDistanceHighFidelity(from: *const Point, to: *const Point) f64 {
    // Squared Euclidean distance
    // Omitting the square root makes this significantly cheaper while
    // maintaining a true high-fidelity mathematical curve.
    const x_diff = to.x - from.x;
    const y_diff = to.y - from.y;

    return (x_diff * x_diff) + (y_diff * y_diff);
}

fn getDistanceMediumFidelity(from: *const Point, to: *const Point) f64 {
    // alpha max plus beta min distance
    const x_diff = @abs(to.x - from.x);
    const y_diff = @abs(to.y - from.y);
    const max_diff = if (x_diff > y_diff) x_diff else y_diff;
    const min_diff = if (x_diff > y_diff) y_diff else x_diff;

    return max_diff + (0.5 * min_diff);
}

fn getDistanceLowFidelity(from: *const Point, to: *const Point) f64 {
    // chebyshev distance
    const x_diff = @abs(to.x - from.x);
    const y_diff = @abs(to.y - from.y);

    return if (x_diff > y_diff) x_diff else y_diff;
}

fn getDistanceVeryLowFidelity(from: *const Point, to: *const Point) f64 {
    return (to.x - from.x) + (to.y - from.y);
}

const Type = enum { MED, LOW };
//const Type = enum { HIGH, MED, LOW };

pub fn distCom(comptime policy: Type, from: *const Point, to: *const Point) f64 {
    switch (policy) {
        .HIGH => return getDistanceHighFidelity(from, to),
        .MED => return getDistanceMediumFidelity(from, to),
        .LOW => return getDistanceLowFidelity(from, to),
        .VERY_LOW => return getDistanceVeryLowFidelity(from, to),
    }
}

pub fn distRun(policy: Type, from: *const Point, to: *const Point) f64 {
    switch (policy) {
        .HIGH => return getDistanceHighFidelity(from, to),
        .MED => return getDistanceMediumFidelity(from, to),
        .LOW => return getDistanceLowFidelity(from, to),
        .VERY_LOW => return getDistanceVeryLowFidelity(from, to),
    }
}

const INPUT_SIZE = 100;

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const input = try utils.readFromFile(1000, i32, io, "input_transformation.txt");

    //   print("This is the array of 1000 numbers... \n", .{});
    // _ = try utils.printArray(&input);

    var prng = std.rand.DefaultPrng.init(42);

    var start_time = std.Io.Clock.now(.awake, io);

    var sum: f64 = 0;

    for (0..1000) |_| {
        for (0..input.len - 3) |index| {
            const from = Point{ .x = input[index], .y = input[index + 1] };

            const to = Point{ .x = input[index + 2], .y = input[index + 3] };

            const runtime_policy: Type = @enumFromInt(prng.rand.uintLessThan(u8, 4));

            sum += distRun(runtime_policy, &from, &to);
            sum += distCom(runtime_policy, &from, &to);
        }
    }

    const end_time = std.Io.Clock.now(.awake, io);

    const duration = start_time.durationTo(end_time);

    std.debug.print("Processed loop in: {} ns\n", .{duration.toNanoseconds()});
    std.debug.print("sum: {}\n", .{sum});
}
