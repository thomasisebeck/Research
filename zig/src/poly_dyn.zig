const std = @import("std");
const utils = @import("utils.zig");

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

fn testFunction() void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    defer arena.deinit();
    const allocator = arena.allocator();

    var components: std.ArrayList(Component) = .empty;

    // create the dog
    const heapDog = try allocator.create(Dog);
    heapDog.* = Dog{};

    // bind and append
    try components.append(allocator, asDog(heapDog));

    for (components.items) |animal| {
        const result = animal.sound();

        // Print the result out to the console
        std.debug.print("Animal says: {s}\n", .{result});

        // If benchmarking, make sure the compiler doesn't strip the call away
        std.mem.doNotOptimizeAway(result);
    }
}

const Type = enum { CAT, MOUSE, DOG };

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const SIZE = 50;

    var zoo: [SIZE]Component = undefined;
    var sound_outputs: [SIZE]SoundEnum = undefined;

    // construct static polymorphism array
    var global_cat = Cat{};
    var global_dog = Dog{};
    var global_mouse = Mouse{};

    // bind the function calls
    zoo[0] = asCat(&global_cat);
    zoo[1] = asDog(&global_dog);
    zoo[2] = asMouse(&global_mouse);
    zoo[3] = asCat(&global_cat);
    zoo[4] = asCat(&global_cat);
    zoo[5] = asDog(&global_dog);
    zoo[6] = asMouse(&global_mouse);
    zoo[7] = asDog(&global_dog);
    zoo[8] = asCat(&global_cat);
    zoo[9] = asMouse(&global_mouse);
    zoo[10] = asDog(&global_dog);
    zoo[11] = asCat(&global_cat);
    zoo[12] = asMouse(&global_mouse);
    zoo[13] = asMouse(&global_mouse);
    zoo[14] = asDog(&global_dog);
    zoo[15] = asCat(&global_cat);
    zoo[16] = asDog(&global_dog);
    zoo[17] = asMouse(&global_mouse);
    zoo[18] = asCat(&global_cat);
    zoo[19] = asDog(&global_dog);
    zoo[20] = asMouse(&global_mouse);
    zoo[21] = asMouse(&global_mouse);
    zoo[22] = asCat(&global_cat);
    zoo[23] = asDog(&global_dog);
    zoo[24] = asDog(&global_dog);
    zoo[25] = asCat(&global_cat);
    zoo[26] = asMouse(&global_mouse);
    zoo[27] = asCat(&global_cat);
    zoo[28] = asDog(&global_dog);
    zoo[29] = asMouse(&global_mouse);
    zoo[30] = asCat(&global_cat);
    zoo[31] = asMouse(&global_mouse);
    zoo[32] = asDog(&global_dog);
    zoo[33] = asMouse(&global_mouse);
    zoo[34] = asDog(&global_dog);
    zoo[35] = asCat(&global_cat);
    zoo[36] = asDog(&global_dog);
    zoo[37] = asCat(&global_cat);
    zoo[38] = asMouse(&global_mouse);
    zoo[39] = asDog(&global_dog);
    zoo[40] = asCat(&global_cat);
    zoo[41] = asMouse(&global_mouse);
    zoo[42] = asMouse(&global_mouse);
    zoo[43] = asDog(&global_dog);
    zoo[44] = asCat(&global_cat);
    zoo[45] = asDog(&global_dog);
    zoo[46] = asMouse(&global_mouse);
    zoo[47] = asCat(&global_cat);
    zoo[48] = asDog(&global_dog);
    zoo[49] = asMouse(&global_mouse);

    var start_time = std.Io.Clock.now(.awake, io);

    // 3. Run the dynamic polymorphism benchmark loop
    for (zoo, 0..) |animal, ind| {
        sound_outputs[ind] = animal.sound();
        // makes sure that its not removed
        std.mem.doNotOptimizeAway(sound_outputs[ind]);
    }

    const end_time = std.Io.Clock.now(.awake, io);

    const duration = start_time.durationTo(end_time);

    std.debug.print("\n---  VERIFYING OUTPUTS ---\n", .{});

    for (sound_outputs, 0..) |res, i| {
        std.debug.print("Index {}: {s}\n", .{ i, @tagName(res) });
    }

    std.debug.print("Processed in: {} ns\n", .{duration.toNanoseconds()});
}
