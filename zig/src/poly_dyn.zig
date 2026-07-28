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
    destroyFn: *const fn (*anyopaque, std.mem.Allocator) void,

    pub fn sound(self: Component) SoundEnum {
        return self.makeSound(self.ptr);
    }
    pub fn destroy(self: Component, allocator: std.mem.Allocator) void {
        self.destroyFn(self.ptr, allocator);
    }
};

fn makeDestroyer(comptime T: type) *const fn (*anyopaque, std.mem.Allocator) void {
    return struct {
        fn destroy(p: *anyopaque, allocator: std.mem.Allocator) void {
            const self: *T = @ptrCast(@alignCast(p));
            allocator.destroy(self);
        }
    }.destroy;
}

fn asDog(self: *Dog) Component {
    return .{ .ptr = self, .makeSound = Dog.wrapSound, .destroyFn = makeDestroyer(Dog) };
}
fn asCat(self: *Cat) Component {
    return .{ .ptr = self, .makeSound = Cat.wrapSound, .destroyFn = makeDestroyer(Cat) };
}
fn asMouse(self: *Mouse) Component {
    return .{ .ptr = self, .makeSound = Mouse.wrapSound, .destroyFn = makeDestroyer(Mouse) };
}

const Type = enum { CAT, MOUSE, DOG };

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const SIZE = 21;
    const ITERS = 100;
    var zoo: [SIZE]Component = undefined;
    var sound_outputs: [SIZE * ITERS]SoundEnum = undefined;

    const allocator = std.heap.page_allocator;

    // dynamic = point to single ref
    zoo = .{
        asDog(try allocator.create(Dog)),     asCat(try allocator.create(Cat)),     asMouse(try allocator.create(Mouse)),
        asCat(try allocator.create(Cat)),     asDog(try allocator.create(Dog)),     asMouse(try allocator.create(Mouse)),
        asDog(try allocator.create(Dog)),     asMouse(try allocator.create(Mouse)), asCat(try allocator.create(Cat)),
        asMouse(try allocator.create(Mouse)), asCat(try allocator.create(Cat)),     asDog(try allocator.create(Dog)),
        asMouse(try allocator.create(Mouse)), asDog(try allocator.create(Dog)),     asCat(try allocator.create(Cat)),
        asMouse(try allocator.create(Mouse)), asDog(try allocator.create(Dog)),     asCat(try allocator.create(Cat)),
        asMouse(try allocator.create(Mouse)), asCat(try allocator.create(Cat)),     asDog(try allocator.create(Dog)),
    };

    _ = std.os.linux.prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    var start_time = std.Io.Clock.now(.awake, io);

    var ind: usize = 0;

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

    for (zoo) |component| {

        // Cast the typeless ptr back to an alignment of 1 (or match your struct alignment)
        // so the allocator can safely reclaim the chunk of heap memory
        component.destroy(allocator);
    }
}
