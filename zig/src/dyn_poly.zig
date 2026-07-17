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

pub fn main() void {
    var cat = Cat{};
    var dog = Dog{};
    var mouse = Mouse{};

    // init the zoo with all componenst
    const zoo = [_]Component{
        asCat(&cat),
        asDog(&dog),
        asBird(&mouse),
    };

    // TODO:  start timer
    for (zoo) |animal| {
        const result = animal.sound();
        std.debug.print("An animal says: {s}\n", .{result});
    }
    // TODO: end timer

}
