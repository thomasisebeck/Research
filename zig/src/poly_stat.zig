const std = @import("std");
const print = std.debug.print;

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

pub fn makeSoundHelper(comptime myAnimal: anytype) SoundEnum {
    return myAnimal.sound();
}

pub fn main(init: std.process.Init) !void {
    // --------------- setup writer -------------------
    const io = init.io;

    // FILE WRITER
    var file_buffer: [1024]u8 = undefined;
    const file = try std.Io.Dir.openFile(std.Io.Dir.cwd(), io, "/tmp/perf.ctl", .{ .mode = .write_only });
    var stdout_file_writer: std.Io.File.Writer = .init(file, io, &file_buffer);
    const file_writer = &stdout_file_writer.interface;

    // IO WRITER
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_io_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_io_writer.interface;
    // ------------------------------------------------

    const SIZE = 21;
    const ITERS = 100;

    var sound_outputs: [SIZE * ITERS]SoundEnum = undefined;

    var d1: Dog = .{};
    var d2: Dog = .{};
    var d3: Dog = .{};
    var d4: Dog = .{};
    var d5: Dog = .{};
    var d6: Dog = .{};
    var d7: Dog = .{};
    var c1: Cat = .{};
    var c2: Cat = .{};
    var c3: Cat = .{};
    var c4: Cat = .{};
    var c5: Cat = .{};
    var c6: Cat = .{};
    var c7: Cat = .{};
    var m1: Mouse = .{};
    var m2: Mouse = .{};
    var m3: Mouse = .{};
    var m4: Mouse = .{};
    var m5: Mouse = .{};
    var m6: Mouse = .{};
    var m7: Mouse = .{};

    // static = point to static instance
    var zoo = [SIZE]Animal{
        .{ .dog = &d1 },   .{ .cat = &c1 },   .{ .mouse = &m1 },
        .{ .cat = &c2 },   .{ .dog = &d2 },   .{ .mouse = &m2 },
        .{ .dog = &d3 },   .{ .mouse = &m3 }, .{ .cat = &c3 },
        .{ .mouse = &m4 }, .{ .cat = &c4 },   .{ .dog = &d4 },
        .{ .mouse = &m5 }, .{ .dog = &d5 },   .{ .cat = &c5 },
        .{ .mouse = &m6 }, .{ .dog = &d6 },   .{ .cat = &c6 },
        .{ .mouse = &m7 }, .{ .cat = &c7 },   .{ .dog = &d7 },
    };

    var ind: usize = 0;

    _ = try file_writer.print("enable\n", .{});
    try file_writer.flush();
    var start_time = std.Io.Clock.now(.awake, io);

    for (0..ITERS) |_| {
        for (zoo) |animal| {
            sound_outputs[ind] = animal.sound();
            ind += 1;
        }
    }

    const end_time = std.Io.Clock.now(.awake, io);
    _ = try file_writer.print("disable\n", .{});
    try file_writer.flush();

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
    zoo[0] = .{ .dog = &d1 };

    // TODO: remove
    //---------------------- print and clean ------------------
    _ = try stdout_writer.print("Processed in: [{}] ns.", .{duration.toNanoseconds()});
    try stdout_writer.flush();
    //---------------------------------------------------------

    std.mem.doNotOptimizeAway(&zoo);
    std.mem.doNotOptimizeAway(&sound_outputs);
}
