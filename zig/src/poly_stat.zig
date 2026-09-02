const std = @import("std");
const print = std.debug.print;
const utils = @import("utils.zig");

const PR_TASK_PERF_EVENTS_ENABLE: usize = 32;
const PR_TASK_PERF_EVENTS_DISABLE: usize = 33;

const SoundEnum = enum(u8) {
    woof,
    meow,
    squeek,
};

const Dog = struct {
    id: u64 = 1,
    pub fn sound(self: Dog) SoundEnum {
        if (self.id == 0) return SoundEnum.meow;

        return SoundEnum.woof;
    }
};
const Cat = struct {
    id: u64 = 1,
    pub fn sound(self: Cat) SoundEnum {
        if (self.id == 0) return SoundEnum.woof;

        return SoundEnum.meow;
    }
};
const Mouse = struct {
    id: u64 = 1,
    pub fn sound(self: Mouse) SoundEnum {
        if (self.id == 0) return SoundEnum.woof;

        return SoundEnum.squeek;
    }
};

const Animal = union(enum) {
    cat: *const Cat,
    dog: *const Dog,
    mouse: *const Mouse,

    // This method handles the direct, high-performance static branch lookup
    pub fn sound(self: Animal) SoundEnum {
        return switch (self) {
            .cat => |c| c.sound(),
            .dog => |d| d.sound(),
            .mouse => |m| m.sound(),
        };
    }
};

//      pub fn makeSoundHelper(comptime myAnimal: anytype) SoundEnum {
//          return myAnimal.sound();
//      }

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

    const SIZE = 100;
    const ITERS = 100;
    var sound_outputs: [SIZE * ITERS]SoundEnum = undefined;

    var dog = Dog{};
    var cat = Cat{};
    var mouse = Mouse{};

    var zoo: [SIZE]Animal = undefined;

    var ind: usize = 0;

    const input_arr = try utils.readArrayFromFile(i32, SIZE, io, "animals.txt");

    // popluate the zoo array
    // 0 -> Dog, 1 -> Cat, 2 -> Mouse
    for (0..SIZE) |i| {
        zoo[i] = switch (input_arr[i]) {
            1 => .{ .dog = &dog },
            2 => .{ .cat = &cat },
            3 => .{ .mouse = &mouse },
            else => unreachable,
        };
    }

    // prevents entire loop from being eval at comptime
    std.mem.doNotOptimizeAway(&zoo);


    // --------------- start perf, then the clock ---------------- //
    try utils.sendPerfCommand(ctl_writer, ack_reader, "enable");
    const start_time = std.Io.Clock.now(.awake, io);
    // ----------------------------------------------------------- //

    for (0..ITERS) |_| {
        for (zoo) |animal| {
            sound_outputs[ind] = animal.sound();
            ind += 1;
        }
    }

    // -------------- stop the clock, then end perf -------------- //
    try utils.sendPerfCommand(ctl_writer, ack_reader, "disable");
    const end_time = std.Io.Clock.now(.awake, io);
    // ----------------------------------------------------------- //

    const duration = start_time.durationTo(end_time);

    //---------------------- print and clean ------------------
    _ = try stdout_writer.print("Processed in: [{}] ns.", .{duration.toNanoseconds()});
    try stdout_writer.flush();
    //---------------------------------------------------------

    _ = try stdout_writer.print("\n---  VERIFYING OUTPUTS ---\n", .{});
    for (sound_outputs, 0..) |res, i| {
        _ = try stdout_writer.print("Index {}: {s}\n", .{ i, @tagName(res) });
    }
    try stdout_writer.flush();

    // must mutate
    zoo[0] = .{ .dog = &dog };

    // black box sound outputs after
    std.mem.doNotOptimizeAway(&sound_outputs);
}
