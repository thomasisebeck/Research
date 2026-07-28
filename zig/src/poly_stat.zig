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
    cat: Cat,
    dog: Dog,
    mouse: Mouse,

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

    // static = point to static instance
    const zoo = [SIZE]Animal{
        .{ .dog = Dog{} },     .{ .cat = Cat{} },     .{ .mouse = Mouse{} },
        .{ .cat = Cat{} },     .{ .dog = Dog{} },     .{ .mouse = Mouse{} },
        .{ .dog = Dog{} },     .{ .mouse = Mouse{} }, .{ .cat = Cat{} },
        .{ .mouse = Mouse{} }, .{ .cat = Cat{} },     .{ .dog = Dog{} },
        .{ .mouse = Mouse{} }, .{ .dog = Dog{} },     .{ .cat = Cat{} },
        .{ .mouse = Mouse{} }, .{ .dog = Dog{} },     .{ .cat = Cat{} },
        .{ .mouse = Mouse{} }, .{ .cat = Cat{} },     .{ .dog = Dog{} },
    };
    _ = std.os.linux.prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    var start_time = std.Io.Clock.now(.awake, io);

    var ind: usize = 0;

    // Look! A completely standard runtime for loop. No 'inline' needed!
    for (0..ITERS) |_| {
        for (zoo) |animal| {
            sound_outputs[ind] = animal.sound();
            ind += 1;
        }
    }

    const end_time = std.Io.Clock.now(.awake, io);
    _ = std.os.linux.prctl(PR_TASK_PERF_EVENTS_DISABLE, 0, 0, 0, 0);

    const duration = start_time.durationTo(end_time);

    std.debug.print("\n---  VERIFYING OUTPUTS ---\n", .{});
    for (sound_outputs, 0..) |res, i| {
        std.debug.print("Index {}: {s}\n", .{ i, @tagName(res) });
    }
    std.debug.print("Processed in: {} ns\n", .{duration.toNanoseconds()});
}
