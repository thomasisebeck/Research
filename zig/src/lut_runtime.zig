const std = @import("std");
const utils = @import("utils.zig");

const PR_TASK_PERF_EVENTS_ENABLE: usize = 32;
const PR_TASK_PERF_EVENTS_DISABLE: usize = 33;

// TODO: this is the experimental change
// 1 increment -> must still test
// 0.1 increment -> comptime is faster, fits in the L1 cache
// 0.01 increment -> runtime is faster, does not fit in the L1 cache

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

    const test_cases: [utils.TEST_SIZE]f64 = try utils.readArrayFromFile(f64, utils.TEST_SIZE, init.io, "lookup.txt");

    var warmup_sum: f64 = 0;
    var sum: f64 = 0;
    const ITERS: usize = 100;

    // test cases is i64 arr
    // num / increment, making it larger (if inc between 0 and 1)
    for (0..ITERS) |_| {
        for (test_cases) |num| {
            warmup_sum += @sin(num) + @cos(num);
        }
    }

    std.mem.doNotOptimizeAway(warmup_sum);

    // --- BENCMARK ---
    // Calculate the actual values

    // --------------- start perf, then the clock ---------------- //
    try utils.sendPerfCommand(ctl_writer, ack_reader, "enable");
    const start_time = std.Io.Clock.now(.awake, io);
    // ----------------------------------------------------------- //

    // dynamic
    for (0..ITERS) |_| {
        for (test_cases) |num| {
            // no need to offset here, we just use the test case as is
            sum += @sin(num) + @cos(num);
        }
    }

    std.mem.doNotOptimizeAway(sum);

    // -------------- stop the clock, then end perf -------------- //
    const end_time = std.Io.Clock.now(.awake, io);
    try utils.sendPerfCommand(ctl_writer, ack_reader, "disable");
    // ----------------------------------------------------------- //

    const duration = start_time.durationTo(end_time);

    //---------------------- print and clean ------------------
    _ = try stdout_writer.print("Processed in: [{}] ns. Sum: {}", .{ duration.toNanoseconds(), sum });
    try stdout_writer.flush();
    //---------------------------------------------------------

}
