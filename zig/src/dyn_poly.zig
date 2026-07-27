const std = @import("std");

const Dog = struct {};
const Cat = struct {};
const Mouse = struct {};

const Component = struct {
    ptr: *anyopaque,
    makeSound: *const fn (*anyopaque) []const u8,

    pub fn sound(self: Component) []const u8 {
        return self.makeSound(self.ptr);
    }
};

fn bark(ptr: *anyopaque) []const u8 {
    _ = ptr;
    return "woof";
}

fn meow(ptr: *anyopaque) []const u8 {
    _ = ptr;
    return "meow";
}

fn squeek(ptr: *anyopaque) []const u8 {
    _ = ptr;
    return "squeek";
}

fn asDog(self: *Dog) Component {
    return .{ .ptr = self, .makeSound = bark };
}

fn asCat(self: *Cat) Component {
    return .{ .ptr = self, .makeSound = meow };
}

fn asBird(self: *Mouse) Component {
    return .{ .ptr = self, .makeSound = squeek };
}

pub fn makeSoundHelper(comptime myAnimal: anytype) void {
    myAnimal.sound();
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var cat = Cat{};
    var dog = Dog{};
    var mouse = Mouse{};

    const ZOO_SIZE = 100_000;
    var zoo: [ZOO_SIZE]Component = undefined;

    // Populate the array with each animal
    var i: usize = 0;
    while (i < ZOO_SIZE) : (i += 3) {
        if (i + 0 < ZOO_SIZE) zoo[i + 0] = asCat(&cat);
        if (i + 1 < ZOO_SIZE) zoo[i + 1] = asDog(&dog);
        if (i + 2 < ZOO_SIZE) zoo[i + 2] = asBird(&mouse);
    }

    var start_time = std.Io.Clock.now(.awake, io);

    // 3. Run the dynamic polymorphism benchmark loop
    for (zoo) |animal| {
        const result = animal.sound();

        // makes sure that its not removed
        std.mem.doNotOptimizeAway(result);
    }

    const end_time = std.Io.Clock.now(.awake, io);

    const duration = start_time.durationTo(end_time);

    std.debug.print("Processed in: {} ns\n", .{duration.toNanoseconds()});
}
