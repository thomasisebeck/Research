const std = @import("std");
const utils = @import("utils.zig");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    // --------------- setup io -------------------
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

    // --------------- start perf, then the clock ---------------- //
    try utils.sendPerfCommand(ctl_writer, ack_reader, "enable");
    const start_time = std.Io.Clock.now(.awake, io);
    // ----------------------------------------------------------- //

    // Measured payload
    _ = try stdout_writer.print("Hello, World!\n", .{});

    // -------------- stop the clock, then end perf -------------- //
    const end_time = std.Io.Clock.now(.awake, io);
    try utils.sendPerfCommand(ctl_writer, ack_reader, "disable");
    // ----------------------------------------------------------- //

    const duration = start_time.durationTo(end_time);

    //---------------------- print and clean ------------------
    _ = try stdout_writer.print("Processed in: [{}] ns\n", .{duration.toNanoseconds()});
    try stdout_writer.flush();
    //---------------------------------------------------------
}
