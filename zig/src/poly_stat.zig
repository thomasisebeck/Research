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

pub fn makeSoundHelper(comptime myAnimal: anytype) SoundEnum {
    return myAnimal.sound();
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const SIZE = 50;

    const types = [SIZE]type{
        Cat,   Dog,   Mouse, Cat,   Cat,   Dog,   Mouse,
        Dog,   Cat,   Mouse, Dog,   Cat,   Mouse, Mouse,
        Dog,   Cat,   Dog,   Mouse, Cat,   Dog,   Mouse,
        Mouse, Cat,   Dog,   Dog,   Cat,   Mouse, Cat,
        Dog,   Mouse, Cat,   Mouse, Dog,   Mouse, Dog,
        Cat,   Dog,   Cat,   Mouse, Dog,   Cat,   Mouse,
        Mouse, Dog,   Cat,   Dog,   Mouse, Cat,   Dog,
        Mouse,
    };

    // Instantiate our compile-time heterogeneous tuple collection
    const ZooTuple = std.meta.Tuple(&types);
    var duck_zoo: ZooTuple = undefined;
    var sound_outputs: [SIZE]SoundEnum = undefined;

    // Initialize every structural slot
    inline for (&duck_zoo, 0..) |*animal, i| {
        animal.* = types[i]{};
    }

    var start_time = std.Io.Clock.now(.awake, io);

    inline for (duck_zoo, 0..) |animal, i| {
        sound_outputs[i] = makeSoundHelper(animal);
    }

    const end_time = std.Io.Clock.now(.awake, io);

    std.debug.print("\n---  VERIFYING OUTPUTS ---\n", .{});
    for (sound_outputs, 0..) |res, i| {
        std.debug.print("Index {}: {s}\n", .{ i, @tagName(res) });
    }

    const duration = start_time.durationTo(end_time);

    std.debug.print("Processed in: {} ns\n", .{duration.toNanoseconds()});
}
