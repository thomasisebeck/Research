const std = @import("std");
const utils = @import("utils.zig");

const PR_TASK_PERF_EVENTS_ENABLE: usize = 32;
const PR_TASK_PERF_EVENTS_DISABLE: usize = 33;

// TODO: this is the experimental change
// 1 increment -> must still test
// 0.1 increment -> comptime is faster, fits in the L1 cache
// 0.01 increment -> runtime is faster, does not fit in the L1 cache

pub fn main(init: std.process.Init) !void {

    // --------------- setup writer -------------------
    const io = init.io;
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;
    // ------------------------------------------------

    const test_cases: [utils.TEST_SIZE]f64 = try utils.readArrayFromFile(utils.TEST_SIZE, init.io, "lookup.txt");


    // --- BENCMARK ---
    // Calculate the actual values
    var sum: f64 = 0;

    _ = std.os.linux.prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    const start_time = std.Io.Clock.now(.awake, io);

    // dynamic
    for (test_cases) |num| {
        // no need to offset here, we just use the test case as is
        sum += @sin(num) + @cos(num);
    }

    const end_time = std.Io.Clock.now(.awake, io);
    _ = std.os.linux.prctl(PR_TASK_PERF_EVENTS_DISABLE, 0, 0, 0, 0);

    const duration = start_time.durationTo(end_time);

    //---------------------- print and clean ------------------
    _ = try stdout_writer.print("Processed in: [{}] ns. Sum: {}", .{duration.toNanoseconds(), sum});
    try stdout_writer.flush();
    //---------------------------------------------------------

    std.mem.doNotOptimizeAway(sum);
}
