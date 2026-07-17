const Dog = struct {
    pub fn sound() void {


    }
};
const Cat = struct {};
const Mouse = struct {};

fn makeSoundStatic(inputType: anytype) void {
    inputType.sound();
}
