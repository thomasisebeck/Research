const std = @import("std");

const RuntimeCalc = struct {
    val: f64,

    pub fn init(initValue: f64) RuntimeCalc {
        return .{ .val = initValue };
    }

    pub fn add(self: RuntimeCalc, other: f64) RuntimeCalc {
        return .{ .val = self.val + other };
    }

    pub fn sub(self: RuntimeCalc, other: f64) RuntimeCalc {
        return .{ .val = self.val - other };
    }

    pub fn mul(self: RuntimeCalc, other: f64) RuntimeCalc {
        return .{ .val = self.val * other };
    }

    pub fn div(self: RuntimeCalc, other: f64) RuntimeCalc {
        return .{ .val = self.val / other };
    }
};

const ReadError = error{TooManyNumbers};

// take in a string as the file name

// fn runtime(io: anytype) !i64 {
//     var stdout_writer = std.Io.File.stdout().writer(io, &.{});
//     const stdout = &stdout_writer.interface;

//     try stdout.print("---- runtime ----\n");
//     try stdout.print("Reading 4 dynamic numbers from foo.txt...\n");

//     var file = try std.Io.Dir.cwd().openFile(io, "foo.txt", .{});
//     defer file.close(io);

//     var file_buf: [1024]u8 = undefined;
//     var in_stream = file.reader(io, &file_buf);

//     //    var buf: [1024]u8 = undefined;
//     var input = [_]f64{0.0} ** 4;
//     var counter: usize = 0;

//     while (true) {
//         // 1. Read up to the newline using the new method
//         const line = in_stream.interface.takeDelimiterExclusive('\n') catch |err| switch (err) {
//             error.EndOfStream => break, // Safely end the loop on EOF
//             else => return err, // Propagate any other real I/O errors
//         };

//         // 2. Clean trailing carriage returns for cross-platform safety
//         const clean_line = std.mem.trimEnd(u8, line, "\r");

//         if (counter >= 4) return 1;

//         // 3. Parse and store
//         input[counter] = try std.fmt.parseFloat(f64, clean_line);
//         counter += 1;
//     }

//     //  while (try in_stream.interface.readUntilDelimiterOrEof(&buf, '\n')) |line| {
//     //      const clean_line = std.mem.trimRight(u8, line, "\r");

//     //      if (counter >= 4)
//     //          return 1;

//     //      input[counter] = std.fmt.parseInt(i64, clean_line);
//     //      counter += 1;
//     //  }

//     try stdout.print("input is: \n\t {any}\n", .{input});

//     // init the calc
//     const r = RuntimeCalc.init(input[0]);

//     const result = r.add(input[1]).mul(input[2]).div(input[3]);

//     try stdout.print("Runtime Result: {d}\n", result);

//     return 0;
// }

fn readFromFile(io: std.Io) !void {
    var stdout_writer = std.Io.File.stdout().writer(io, &.{});
    const stdout = &stdout_writer.interface;
    var file_buf: [1024]u8 = undefined;
    const file = try std.Io.Dir.cwd().readFile(io, "input.txt", &file_buf);

    try stdout.print("This is the line: {s}\n", .{file});
}

fn writeToFile(io: std.Io) !void {
    const file = try std.Io.Dir.cwd().createFile(io, "output.txt", .{});
    defer file.close(io);

    try file.writeStreamingAll(io, "Hello there!");
}

//pub fn main(init: std.process.Init) !void {
pub fn main(init: std.process.Init) !void {
    const io = init.io;

    _ = try readFromFile(io);
}
