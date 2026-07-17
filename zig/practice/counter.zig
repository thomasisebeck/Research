const std = @import("std");

// other files cannot see this, because not pub
var num_creations: u32 = 0;

const Counter = @This();

_value: i32,

// return the type of this file (constructor)
pub fn init(start_value: i32) Counter {
    num_creations += 1;

    // init the counter with the value passed into this function
    return Counter{
        ._value = start_value,
    };
}

// have to take in a modifiable reference
pub fn increment(self: *Counter) void {
    self._value += 1;
}

pub fn getValue(self: *Counter) i32 {
    return self._value;
}
