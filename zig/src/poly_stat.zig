const std = @import("std");

const Dog = struct {
    pub fn sound() []const u8 {
        return "woof";
    }
};
const Cat = struct {
    pub fn sound() []const u8 {
        return "meow";
    }
};
const Mouse = struct {
    pub fn sound() []const u8 {
        return "squeek";
    }
};

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
