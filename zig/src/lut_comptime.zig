const std = @import("std");
const utils = @import("utils.zig");

const PR_TASK_PERF_EVENTS_ENABLE: usize = 32;
const PR_TASK_PERF_EVENTS_DISABLE: usize = 33;
const linux = std.os.linux;

// TODO: this is the experimental change
// 1 increment -> must still test
// 0.1 increment -> comptime is faster, fits in the L1 cache
// 0.01 increment -> runtime is faster, does not fit in the L1 cache

fn generateLUT() [utils.steps]f64 {
    @setEvalBranchQuota(100_000_000);
    // table empty, but enough to hold all the utils.steps
    var table: [utils.steps]f64 = undefined;

    for (&table, 0..) |*item, i| {
        const result: f64 = @as(f64, @floatFromInt(i)) * utils.increment;
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

    for (0..utils.TEST_SIZE) |_| {
        // utils.steps is the max index that you can access in the LUT
        // just store a random index to look up
        // utils.degrees = 360

        // we need anything between 0 and steps (0 - 3600)
        // then the test case becomes 0.1 0.2 0.3 ...
        const val_deg = prng.random().float(f64) * @as(f64, utils.degrees);

        try file_writer.interface.print("{d}\n", .{val_deg});

        std.debug.print("{d},", .{val_deg});
    }
}

// zig build -Dtarget_src=./src/lut_comptime.zig -Dincrement=0.5

pub fn main(init: std.process.Init) !void {

    // --------------- setup io -------------------
    const io = init.io;

    // CTL FILE
    var ctl_file_buffer: [1024]u8 = undefined;
    const ctl_file_open = try std.Io.Dir.openFile(std.Io.Dir.cwd(), io, "/tmp/perf.ctl", .{ .mode = .write_only });
    var ctl_file_writer_struct: std.Io.File.Writer = .init(ctl_file_open, io, &ctl_file_buffer);
    const ctl_writer = &ctl_file_writer_struct.interface;

    // ACK FILE
    var ack_file_buffer: [1024]u8 = undefined;
    const ack_file_open = try std.Io.Dir.openFile(std.Io.Dir.cwd(), io, "/tmp/perf.ack", .{ .mode = .read_only });
    var ack_file_reader_struct: std.Io.File.Reader = .init(ack_file_open, io, &ack_file_buffer);
    const ack_reader = &ack_file_reader_struct.interface;

    // IO WRITER
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_io_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_io_writer.interface;
    // ------------------------------------------------

   // _ = try generateTestCases(init.io, "lookup.txt");
    const test_cases: [utils.TEST_SIZE]f64 = try utils.readArrayFromFile(f64, utils.TEST_SIZE, init.io, "lookup.txt");

    // needs to be var for the volatile cast
    const my_lut = comptime generateLUT();

    // faster, but not fair
    // keep the LUT on the function stack by marking it as volatile
    // const my_lut: *volatile [utils.steps]f64 = @volatileCast(&comp_lut);

    const prediv: f64 = 1.0 / utils.increment;
    var warmup_sum: f64 = 0;
    var sum: f64 = 0;
    const ITERS: usize = 100;

    // test cases is i64 arr
    // num / increment, making it larger (if inc between 0 and 1)
    for (0..ITERS) |_| {
        for (test_cases) |num| {
            const idx: usize = @intFromFloat(num * prediv);

            warmup_sum += my_lut[idx];
        }
    }

    std.mem.doNotOptimizeAway(warmup_sum);

    // --------------- start perf, then the clock ---------------- //
    try utils.sendPerfCommand(ctl_writer, ack_reader, "enable");
    const start_time = std.Io.Clock.now(.awake, io);
    // ------------------------------------------------------
    //
     //++ / Zig Conservative Aliasing: Because raw pointers and standard references in C++ and Zig allow for potential aliasing (where writing to sum might theoretically modify the memory backing the array), LLVM's alias analyzer must take the conservative path and re-read the array from memory on every outer iteration to remain spec-compliant.

    // test cases is i64 arr
    // num / increment, making it larger (if inc between 0 and 1)
    for (0..ITERS) |_| {
        for (test_cases) |num| {
            const idx: usize = @intFromFloat(num * prediv);

            sum += my_lut[idx];
        }
    }

    std.mem.doNotOptimizeAway(sum);

    // -------------- stop the clock, then end perf -------------- //
    const end_time = std.Io.Clock.now(.awake, io);
    try utils.sendPerfCommand(ctl_writer, ack_reader, "disable");
    // ----------------------------------------------------------- //

    const duration = start_time.durationTo(end_time);

    //---------------------- print and clean ------------------
    _ = try stdout_writer.print("Processed in: [{}] ns. Sum: {}, warmup sum: {}", .{ duration.toNanoseconds(), sum , warmup_sum});
    try stdout_writer.flush();
    //---------------------------------------------------------
}
