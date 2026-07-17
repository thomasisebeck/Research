const std = @import("std");
const expEq = std.testing.expectEqual;
const Counter = @import("counter.zig");

fn debugPrint() !void {
    var x: i32 = 1;
    comptime var y: i32 = 1;

    x += 1;
    y += 2;

    try expEq(2, x);
    try expEq(3, y);

    // compile time check
    comptime if (y != 3) {
        @compileError("y value is incorrect");
    };

    std.debug.print("x: {}\n", .{x});
    std.debug.print("y: {}\n", .{y});
}

fn checkCounter() void {
    var my_counter = Counter.init(10);

    std.debug.print("init counter value: {}\n", .{my_counter.getValue()});

    my_counter.increment();

    std.debug.print("new counter value: {}\n", .{my_counter.getValue()});
}

pub fn main() !void {
    // try debugPrint();
    checkCounter();
}
