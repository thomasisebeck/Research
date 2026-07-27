const std = @import("std");
const utils = @import("utils.zig");

const Dog = struct {
    pub fn sound(self: Dog) []const u8 {
        _ = self;
        return "woof";
    }

    // Type-erased wrapper for the sound call
    pub fn wrapSound(p: *anyopaque) []const u8 {
        // Re-align and cast the typeless pointer back into a Dog
        const self: *const Dog = @ptrCast(@alignCast(p));
        return self.sound();
    }

    pub fn destroy(p: *anyopaque, a: std.mem.Allocator) void {
        a.destroy(@as(*Dog, @ptrCast(@alignCast(p))));
    }
};

const Cat = struct {
    pub fn sound(self: Cat) []const u8 {
        _ = self;
        return "meow";
    }

    pub fn wrapSound(p: *anyopaque) []const u8 {
        const self: *const Cat = @ptrCast(@alignCast(p));
        return self.sound();
    }

    pub fn destroy(p: *anyopaque, a: std.mem.Allocator) void {
        a.destroy(@as(*Cat, @ptrCast(@alignCast(p))));
    }
};

const Mouse = struct {
    pub fn sound(self: Mouse) []const u8 {
        _ = self;
        return "squeek";
    }

    pub fn wrapSound(p: *anyopaque) []const u8 {
        const self: *const Mouse = @ptrCast(@alignCast(p));
        return self.sound();
    }

    pub fn destroy(p: *anyopaque, a: std.mem.Allocator) void {
        a.destroy(@as(*Mouse, @ptrCast(@alignCast(p))));
    }
};

const Component = struct {
    ptr: *anyopaque,
    makeSound: *const fn (*anyopaque) []const u8,
    destroyFn: *const fn (*anyopaque, std.mem.Allocator) void,

    pub fn sound(self: Component) []const u8 {
        return self.makeSound(self.ptr);
    }
};

fn asDog(self: *Dog) Component {
    return .{
        // keep a ptr to myself to do destruction
        .ptr = self,
        // Pass the function refs
        .makeSound = Dog.wrapSound,
        .destroyFn = Dog.destroy,
    };
}

fn asCat(self: *Cat) Component {
    return .{
        .ptr = self,
        .makeSound = Cat.wrapSound,
        .destroyFn = Cat.destroy,
    };
}

fn asMouse(self: *Mouse) Component {
    return .{
        .ptr = self,
        .makeSound = Mouse.wrapSound,
        .destroyFn = Mouse.destroy,
    };
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

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const SIZE = 500;
    //try utils.generateRandomArray(SIZE, io, "animals.txt");
    const myArr = try utils.readArrayFromFile(SIZE, io, "animals.txt");

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const aa = arena.allocator();

    var components: std.ArrayList(Component) = .empty;

    for (myArr) |ind| {

        // construct the animals on the fly
        switch (ind) {
            1 => {
                // allocate
                const heapDog = try aa.create(Dog);
                heapDog.* = Dog{};

                // bind and append
                try components.append(aa, asDog(heapDog));
            },
            2 => {
                // allocate
                const heapDog = try aa.create(Dog);
                heapDog.* = Dog{};

                // bind and append
                try components.append(aa, asDog(heapDog));
            },
            3 => {
                // allocate
                const heapMouse = try aa.create(Mouse);
                heapMouse.* = Mouse{};

                // bind and append
                try components.append(aa, asMouse(heapMouse));
            },
            else => {
                @panic("invalid animal");
            },
        }
    }

    var buffer: [SIZE][]const u8 = undefined;

    // start the timer

    for (components.items, 0..) |animal, ind| {
        buffer[ind] = animal.sound();
    }
    // stop the timer

    for (0..SIZE) |ind| {
        std.debug.print("Stored sound: {s}\n", .{buffer[ind]});
    }
}
