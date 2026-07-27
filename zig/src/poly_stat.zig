const std = @import("std");

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
};
const Cat = struct {
    pub fn sound(self: Cat) SoundEnum {
        _ = self;

        return SoundEnum.meow;
    }
};
const Mouse = struct {
    pub fn sound(self: Mouse) SoundEnum {
        _ = self;

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

    const SIZE = 3;
    var sound_outputs: [SIZE]SoundEnum = undefined;

    // A perfectly normal, runtime-accessible array!
    // Every element is an identical 'Animal' container.
    const zoo = [SIZE]Animal{
        .{ .cat = Cat{} },
        .{ .dog = Dog{} },
        .{ .mouse = Mouse{} },
    };

    var start_time = std.Io.Clock.now(.awake, io);

    // Look! A completely standard runtime for loop. No 'inline' needed!
    for (zoo, 0..) |animal, i| {
        sound_outputs[i] = animal.sound();
    }

    const end_time = std.Io.Clock.now(.awake, io);
    const duration = start_time.durationTo(end_time);

    std.debug.print("\n---  VERIFYING OUTPUTS ---\n", .{});
    for (sound_outputs, 0..) |res, i| {
        std.debug.print("Index {}: {s}\n", .{ i, @tagName(res) });
    }
    std.debug.print("Processed in: {} ns\n", .{duration.toNanoseconds()});
}
