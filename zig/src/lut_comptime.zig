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
    @setEvalBranchQuota(1000000);
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

    // --------------- setup writer -------------------
    const io = init.io;

    // Control FIFO (Write "enable\n" / "disable\n")
    var file_buffer: [1024]u8 = undefined;
    const file = try std.Io.Dir.openFile(std.Io.Dir.cwd(), io, "/tmp/perf.ctl", .{ .mode = .write_only });
    defer file.close(io);
    var stdout_file_writer: std.Io.File.Writer = .init(file, io, &file_buffer);
    const file_writer: *std.Io.Writer = &stdout_file_writer.interface;

    // Ack FIFO (Read "ack\n" back from perf)
    var ack_buffer: [1024]u8 = undefined;
    const ack_file = try std.Io.Dir.openFile(std.Io.Dir.cwd(), io, "/tmp/perf.ack", .{ .mode = .read_only });
    defer ack_file.close(io);
    var ack_file_reader: std.Io.File.Reader = .init(ack_file, io, &ack_buffer);
    const ack_reader: *std.Io.Reader = &ack_file_reader.interface;

    // Stdout Writer
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_io_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer: *std.Io.Writer = &stdout_io_writer.interface;
    // ------------------------------------------------

    // _ = try generateTestCases(init.io, "lookup.txt");
    const test_cases: [utils.TEST_SIZE]f64 = try utils.readArrayFromFile(f64, utils.TEST_SIZE, init.io, "lookup.txt");

    // needs to be var for the volatile cast
    var compLut = comptime generateLUT();

    // keep the LUT on the function stack by marking it as volatile
    const myLut: *volatile [utils.steps]f64 = @volatileCast(&compLut);

    const prediv: f64 = 1.0 / utils.increment;

    var sum: f64 = 0;

    // ---------------- PERF HANDSHAKE START ----------------
    // 1. Command perf stat to enable counters
    try file_writer.writeAll("enable\n");
    try file_writer.flush();

    // 2. Block until perf replies with "ack\n"
    const raw_ack = try ack_reader.takeDelimiter('\n') orelse unreachable;
    _ = std.mem.trim(u8, raw_ack, "\r");
    // ------------------------------------------------------

    var start_time = std.Io.Clock.now(.awake, io);

    // test cases is i64 arr
    // num / increment, making it larger (if inc between 0 and 1)
    for (test_cases) |num| {
        const idx: usize = @intFromFloat(num * prediv);

        sum += myLut[idx];
    }

    const end_time = std.Io.Clock.now(.awake, io);

    // ---------------- PERF HANDSHAKE END ------------------
    // 3. Command perf stat to disable counters
    _ = try file_writer.print("disable\n", .{});
    try file_writer.flush();
    // ------------------------------------------------------

    const duration = start_time.durationTo(end_time);

    //---------------------- print and clean ------------------
    _ = try stdout_writer.print("Processed in: [{}] ns. Sum: {}", .{ duration.toNanoseconds(), sum });
    try stdout_writer.flush();
    //---------------------------------------------------------

    std.mem.doNotOptimizeAway(sum);
}
