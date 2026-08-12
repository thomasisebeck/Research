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

    std.mem.doNotOptimizeAway(&sound_outputs);

    const duration = start_time.durationTo(end_time);

    std.debug.print("\n---  VERIFYING OUTPUTS ---\n", .{});

    for (sound_outputs, 0..) |res, i| {
        std.debug.print("Index {}: {s}\n", .{ i, @tagName(res) });
    }

    // must mutate
    zoo[0] = asDog(&d1);

    std.debug.print("Processed in: {} ns\n", .{duration.toNanoseconds()});
}
