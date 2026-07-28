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
    pub fn sound(self: Dog) SoundEnum {
        _ = self;
        return SoundEnum.woof;
    }
    pub fn wrapSound(p: *anyopaque) SoundEnum {
        // Re-align and cast the typeless pointer back into a Dog
        const self: *const Dog = @ptrCast(@alignCast(p));
        return self.sound();
    }
};

const Cat = struct {
    pub fn sound(self: Cat) SoundEnum {
        _ = self;
        return SoundEnum.meow;
    }

    pub fn wrapSound(p: *anyopaque) SoundEnum {
        const self: *const Cat = @ptrCast(@alignCast(p));
        return self.sound();
    }
};

const Mouse = struct {
    pub fn sound(self: Mouse) SoundEnum {
        _ = self;
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

    const SIZE = 3;
    var zoo: [SIZE]Component = undefined;
    var sound_outputs: [SIZE]SoundEnum = undefined;

    var global_cat = Cat{};
    var global_dog = Dog{};
    var global_mouse = Mouse{};

    zoo = .{ asCat(&global_cat), asDog(&global_dog), asMouse(&global_mouse) };

    _ = std.os.linux.prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    var start_time = std.Io.Clock.now(.awake, io);

    for (zoo, 0..) |animal, ind| {
        sound_outputs[ind] = animal.sound();
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
