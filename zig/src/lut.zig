const std = @import("std");

const print = std.debug.print;

fn generateLUT(comptime steps: usize, comptime increment: f64) [steps]f64 {

    // table empty, but enough to hold all the sceps
    var table: [steps]f64 = undefined;

    for (&table, 0..) |*item, i| {
        const result: f64 = @as(f64, @floatFromInt(i)) * increment;
        item.* = @sin(result);
    }

    return table;
}

pub fn main() void {
    const degrees: comptime_float = 360;

    // 1.8MB
    //const increment: comptime_float = 0.1;

    //
    const increment: comptime_float = 0.001;

    const step: comptime_int = @intFromFloat(degrees / increment);

    print("step: {d}\n", .{step});

    const myLut = generateLUT(step, increment);

    const toLookUp = [_]f64{ 15.0, 45.0, 120.0 };

    for (toLookUp) |num| {
        const index: usize = @intFromFloat(num / increment);
        print("{d}: {d}\n", .{ num, myLut[index] });
    }
}
