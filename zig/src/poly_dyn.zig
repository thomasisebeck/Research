const std = @import("std");

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

const Component = struct {
    ptr: *anyopaque,
    makeSound: *const fn (*anyopaque) []const u8,
    destroyFn: *const fn (*anyopaque, std.mem.Allocator) void,

    pub fn sound(self: Component) []const u8 {
        return self.makeSound(self.ptr);
    }
};

// Clean binding signature
fn asDog(self: *Dog) Component {
    return .{
        .ptr = self,
        // Pass the function references directly without () parentheses

        .makeSound = Dog.wrapSound,
        .destroyFn = Dog.destroy,
    };
}

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    defer arena.deinit();
    const allocator = arena.allocator();

    var components = std.ArrayList(Component).init(allocator);

    // create the dog
    const heapDog = try allocator.create(Dog);
    heapDog.* = Dog{};

    // bind and append
    components.append(asDog(heapDog));
}
