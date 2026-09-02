const std = @import("std");
const utils = @import("utils.zig");

const SoundEnum = enum(u8) {
    woof,
    meow,
    squeek,
};

const Dog = struct {
    id: u64 = 1,
    pub fn sound(self: Dog) SoundEnum {
        // _ = self;
        if (self.id == 0) return SoundEnum.meow;
        return SoundEnum.woof;
    }
    pub fn asComponent(self: *Dog) Component {
        return Component.init(self);
    }
};

const Cat = struct {
    id: u64 = 1,
    pub fn sound(self: Cat) SoundEnum {
        //_ = self;
        if (self.id == 0) return SoundEnum.woof;
        return SoundEnum.meow;
    }
    pub fn asComponent(self: *Cat) Component {
        return Component.init(self);
    }
};

const Mouse = struct {
    id: u64 = 1,
    pub fn sound(self: Mouse) SoundEnum {
        //_ = self;
        if (self.id == 0) return SoundEnum.woof;
        return SoundEnum.squeek;
    }
    pub fn asComponent(self: *Mouse) Component {
        return Component.init(self);
    }
};

// this is the polymorphic interface
const Component = struct {
    ptr: *anyopaque,
    makeSound: *const fn (*anyopaque) SoundEnum,

    pub fn init(impl: anytype) Component {
        const Wrapper = struct {
            fn sound(ptr: *anyopaque) SoundEnum {
                const self: @TypeOf(impl) = @ptrCast(@alignCast(ptr));
                return self.sound();
            }
        };

        return .{
            .ptr = @ptrCast(@alignCast(impl)),
            .makeSound = Wrapper.sound,
        };
    }

    pub fn sound(self: *const Component) SoundEnum {
        return self.makeSound(self.ptr);
    }
};

const Type = enum { CAT, MOUSE, DOG };

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

    const SIZE = 500;
    const ITERS = 100;
    var sound_outputs: [SIZE * ITERS]SoundEnum = undefined;

    var dog = Dog{};
    var cat = Cat{};
    var mouse = Mouse{};

    var zoo: [SIZE]Component = undefined;

    // read file into array
    const input_arr: [SIZE]i32 = try utils.readArrayFromFile(i32, SIZE, init.io, "animals.txt");

    // put the animals in the array from the stack local copy
    for (input_arr, 0..) |choice, index| {
        zoo[index] = switch (choice) {
            1 => Component.init(&dog),
            2 => Component.init(&cat),
            3 => Component.init(&mouse),
            else => {
                std.debug.print("choice {}", .{choice});
                unreachable;
            },
        };
    }

    std.mem.doNotOptimizeAway(&zoo);

    var ind: usize = 0;


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
    zoo[0] = Component.init(&dog);

    // black box sound outputs after
    std.mem.doNotOptimizeAway(&sound_outputs);
}
