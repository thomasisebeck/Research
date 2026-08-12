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
    cat: *Cat,
    dog: *Dog,
    mouse: *Mouse,

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
    const io = init.io;

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

    std.mem.doNotOptimizeAway(&zoo);

    var ind: usize = 0;

    _ = std.os.linux.prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    var start_time = std.Io.Clock.now(.awake, io);

    for (0..ITERS) |_| {
        for (zoo) |animal| {
            sound_outputs[ind] = animal.sound();
            ind += 1;
        }
    }

    const end_time = std.Io.Clock.now(.awake, io);
    _ = std.os.linux.prctl(PR_TASK_PERF_EVENTS_DISABLE, 0, 0, 0, 0);

    const duration = start_time.durationTo(end_time);

    zoo[0] = .{ .cat = &c1 };
    std.mem.doNotOptimizeAway(&sound_outputs);

    std.debug.print("\n---  VERIFYING OUTPUTS ---\n", .{});
    for (sound_outputs, 0..) |res, i| {
        std.debug.print("Index {}: {s}\n", .{ i, @tagName(res) });
    }
    std.debug.print("Processed in: {} ns\n", .{duration.toNanoseconds()});
}
