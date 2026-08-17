const std = @import("std");

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
        // _ = self;
        if (self.id == 0) return SoundEnum.meow;
        return SoundEnum.woof;
    }
    pub fn wrapSound(p: *anyopaque) SoundEnum {
        // Re-align and cast the typeless pointer back into a Dog
        const self: *const Dog = @ptrCast(@alignCast(p));
        return self.sound();
    }
};

const Cat = struct {
    id: u64 = 1,
    pub fn sound(self: Cat) SoundEnum {
        //_ = self;
        if (self.id == 0) return SoundEnum.woof;
        return SoundEnum.meow;
    }

    pub fn wrapSound(p: *anyopaque) SoundEnum {
        const self: *const Cat = @ptrCast(@alignCast(p));
        return self.sound();
    }
};

const Mouse = struct {
    id: u64 = 1,
    pub fn sound(self: Mouse) SoundEnum {
        //_ = self;
        if (self.id == 0) return SoundEnum.woof;
        return SoundEnum.squeek;
    }

    pub fn wrapSound(p: *anyopaque) SoundEnum {
        const self: *const Mouse = @ptrCast(@alignCast(p));
        return self.sound();
    }
};

const Component = struct {
    ptr: *anyopaque,
    makeSound: *const fn (*anyopaque) SoundEnum,

    pub fn sound(self: Component) SoundEnum {
        return self.makeSound(self.ptr);
    }
};

fn asDog(self: *Dog) Component {
    return .{ .ptr = self, .makeSound = Dog.wrapSound };
}
fn asCat(self: *Cat) Component {
    return .{ .ptr = self, .makeSound = Cat.wrapSound };
}
fn asMouse(self: *Mouse) Component {
    return .{ .ptr = self, .makeSound = Mouse.wrapSound };
}

const Type = enum { CAT, MOUSE, DOG };

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

    _ = try stdout_writer.print("start", .{});
    try stdout_writer.flush();

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

    var zoo = [_]Component{
        asDog(&d1),   asCat(&c1),   asMouse(&m1),
        asCat(&c2),   asDog(&d2),   asMouse(&m2),
        asDog(&d3),   asMouse(&m3), asCat(&c3),
        asMouse(&m4), asCat(&c4),   asDog(&d4),
        asMouse(&m5), asDog(&d5),   asCat(&c5),
        asMouse(&m6), asDog(&d6),   asCat(&c6),
        asMouse(&m7), asCat(&c7),   asDog(&d7),
    };

    std.mem.doNotOptimizeAway(&zoo);

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
    zoo[0] = asDog(&d1);

    // TODO: remove
    //---------------------- print and clean ------------------
    _ = try stdout_writer.print("Processed in: [{}] ns.", .{duration.toNanoseconds()});
    try stdout_writer.flush();
    //---------------------------------------------------------

    std.mem.doNotOptimizeAway(&sound_outputs);
}
