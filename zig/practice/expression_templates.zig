const std = @import("std");
const utils = @import("utls.zig");
const assert = std.debug.assert;
const print = std.debug.print;

const DoCalculation = struct {
    val: f64,

    pub fn init(initValue: f64) DoCalculation {
        return .{ .val = initValue };
    }

    pub fn add(self: DoCalculation, other: f64) DoCalculation {
        return .{ .val = self.val + other };
    }

    pub fn sub(self: DoCalculation, other: f64) DoCalculation {
        return .{ .val = self.val - other };
    }

    pub fn mul(self: DoCalculation, other: f64) DoCalculation {
        return .{ .val = self.val * other };
    }

    pub fn div(self: DoCalculation, other: f64) DoCalculation {
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

fn writeToFile(io: std.Io) !void {
    const file = try std.Io.Dir.cwd().createFile(io, "output.txt", .{});
    defer file.close(io);

    try file.writeStreamingAll(io, "Hello there!");
}

const INPUT_SIZE = 5;

fn dynamicFunction(input: [INPUT_SIZE]i32) DoCalculation {

    // ------- normal compilation -------- //
    // NOTE: function call was left as is and not inlined

    // example.dynamicFunction:
    //     push    rbp
    //     mov     rbp, rsp
    //     sub     rsp, 128
    //     mov     qword ptr [rbp - 128], rsi
    //     mov     qword ptr [rbp - 120], rdi
    //     mov     qword ptr [rbp - 112], rdi
    //     mov     rax, qword ptr [rdx]
    //     mov     qword ptr [rbp - 100], rax
    //     mov     rax, qword ptr [rdx + 8]
    //     mov     qword ptr [rbp - 92], rax
    //     mov     eax, dword ptr [rdx + 16]
    //     mov     dword ptr [rbp - 84], eax
    //     vcvtsi2sd       xmm0, xmm0, dword ptr [rbp - 100]
    //     lea     rdi, [rbp - 80]
    //     call    example.DoCalculation.init
    //     mov     rsi, qword ptr [rbp - 128]
    //     mov     rax, qword ptr [rbp - 80]
    //     mov     qword ptr [rbp - 72], rax
    //     mov     rax, qword ptr [rbp - 72]
    //     mov     qword ptr [rbp - 64], rax
    //     vcvtsi2sd       xmm0, xmm0, dword ptr [rbp - 96]
    //     lea     rdi, [rbp - 56]
    //     lea     rdx, [rbp - 64]
    //     call    example.DoCalculation.add
    //     mov     rsi, qword ptr [rbp - 128]
    //     mov     rax, qword ptr [rbp - 56]
    //     mov     qword ptr [rbp - 48], rax
    //     mov     rax, qword ptr [rbp - 48]
    //     mov     qword ptr [rbp - 40], rax
    //     vcvtsi2sd       xmm0, xmm0, dword ptr [rbp - 92]
    //     lea     rdi, [rbp - 32]
    //     lea     rdx, [rbp - 40]
    //     call    example.DoCalculation.mul
    //     mov     rsi, qword ptr [rbp - 128]
    //     mov     rax, qword ptr [rbp - 32]
    //     mov     qword ptr [rbp - 24], rax
    //     mov     rax, qword ptr [rbp - 24]
    //     mov     qword ptr [rbp - 16], rax
    //     vcvtsi2sd       xmm0, xmm0, dword ptr [rbp - 88]
    //     lea     rdi, [rbp - 8]
    //     lea     rdx, [rbp - 16]
    //     call    example.DoCalculation.div
    //     mov     rdi, qword ptr [rbp - 120]
    //     mov     rax, qword ptr [rbp - 112]
    //     mov     rcx, qword ptr [rbp - 8]
    //     mov     qword ptr [rdi], rcx
    //     add     rsp, 128
    //     pop     rbp
    //     ret

    // ----------- release fast ---------- //

    //.LBB1_495:
    //      vcvtsi2sd       xmm0, xmm15, dword ptr [rbp - 368]
    //      vcvtsi2sd       xmm1, xmm15, dword ptr [rbp - 364]
    //      vaddsd  xmm0, xmm0, xmm1
    //      vcvtsi2sd       xmm1, xmm15, dword ptr [rbp - 360]
    //      vmulsd  xmm0, xmm0, xmm1
    //      vcvtsi2sd       xmm1, xmm15, dword ptr [rbp - 356]
    //      vdivsd  xmm0, xmm0, xmm1
    //      vmovsd  qword ptr [rbp - 48], xmm0
    //      lea     rdi, [rbp - 368]
    //      lea     rsi, [rbp - 336]
    //      call    debug.lockStderr
    //      mov     r12, qword ptr [rbp - 368]
    //      lea     rbx, [r12 + 24]
    //      lea     rax, [rbp - 1583]
    //      mov     qword ptr [rbp - 64], rax
    //      xor     r14d, r14d
    //      lea     r15, [rbp - 472]
    //      jmp     .LBB1_497
    return DoCalculation.init(input[0]).add(input[1]).mul(input[2]).div(input[3]);
}

inline fn inlinedFunction(input: [INPUT_SIZE]i32) DoCalculation {
    // ------- normal compilation -------- //
    // NOTE: inlining only up till one level, the rest is left as is

    //.LBB3_2:
    //   mov     rax, qword ptr [rbp - 136]
    //   mov     qword ptr [rbp - 116], rax
    //   mov     rax, qword ptr [rbp - 128]
    //   mov     qword ptr [rbp - 108], rax
    //   mov     eax, dword ptr [rbp - 120]
    //   mov     dword ptr [rbp - 100], eax
    //   vcvtsi2sd       xmm0, xmm0, dword ptr [rbp - 116]
    //   lea     rdi, [rbp - 96]
    //   call    example.DoCalculation.init
    //   mov     rsi, qword ptr [rbp - 264]
    //   mov     rax, qword ptr [rbp - 96]
    //   mov     qword ptr [rbp - 88], rax
    //   mov     rax, qword ptr [rbp - 88]
    //   mov     qword ptr [rbp - 80], rax
    //   vcvtsi2sd       xmm0, xmm0, dword ptr [rbp - 112]
    //   lea     rdi, [rbp - 72]
    //   lea     rdx, [rbp - 80]
    //   call    example.DoCalculation.add
    //   mov     rsi, qword ptr [rbp - 264]
    //   mov     rax, qword ptr [rbp - 72]
    //   mov     qword ptr [rbp - 64], rax
    //   mov     rax, qword ptr [rbp - 64]
    //   mov     qword ptr [rbp - 56], rax
    //   vcvtsi2sd       xmm0, xmm0, dword ptr [rbp - 108]
    //   lea     rdi, [rbp - 48]
    //   lea     rdx, [rbp - 56]
    //   call    example.DoCalculation.mul
    //   mov     rsi, qword ptr [rbp - 264]
    //   mov     rax, qword ptr [rbp - 48]
    //   mov     qword ptr [rbp - 40], rax
    //   mov     rax, qword ptr [rbp - 40]
    //   mov     qword ptr [rbp - 32], rax
    //   vcvtsi2sd       xmm0, xmm0, dword ptr [rbp - 104]
    //   lea     rdi, [rbp - 24]
    //   lea     rdx, [rbp - 32]
    //   call    example.DoCalculation.div
    //   lea     rax, [rbp - 24]
    //   mov     qword ptr [rbp - 280], rax
    //   jmp     .LBB3_6

    // ----------- release fast ---------- //
    // NOTE: inlines everything
    // vaddsd, vmulsd, and vdivsd: instructions with the wider xmm registers

    //  .LBB1_476:
    //      vcvtsi2sd       xmm0, xmm15, dword ptr [rbp - 352]
    //      lea     rdi, [rbp - 352]
    //      lea     rsi, [rbp - 320]
    //      vcvtsi2sd       xmm1, xmm15, dword ptr [rbp - 348]
    //      vaddsd  xmm0, xmm0, xmm1
    //      vcvtsi2sd       xmm1, xmm15, dword ptr [rbp - 344]
    //      vmulsd  xmm0, xmm0, xmm1
    //      vcvtsi2sd       xmm1, xmm15, dword ptr [rbp - 340]
    //      vdivsd  xmm0, xmm0, xmm1
    //      vmovsd  qword ptr [rbp - 48], xmm0
    //      call    debug.lockStderr
    //      mov     r12, qword ptr [rbp - 352]
    //      lea     rax, [rbp - 1583]
    //      xor     r14d, r14d
    //      lea     r15, [rbp - 448]
    //      mov     qword ptr [rbp - 96], rax
    //      lea     rbx, [r12 + 24]
    //      jmp     .LBB1_478

    return DoCalculation.init(input[0]).add(input[1]).mul(input[2]).div(input[3]);
}

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    const input = try utils.readFromFile(5, io, "input_expr.txt");

    // start the timer

    // ---- normal compilation ---- //
    //   lea     rdi, [rbp - 24]
    //   lea     rdx, [rbp - 44]
    //   call    example.dynamicFunction
    //   mov     rdi, qword ptr [rbp - 176]
    //   mov     rax, qword ptr [rbp - 24]
    //   mov     qword ptr [rbp - 16], rax

    const dyn = dynamicFunction(input);

    // stop the timer

    print("runtime: {}\n", .{dyn.val});

    // start the timer

    // ------- normal compilation -------- //

    // NOTE: only top level function call was inlined
    // The rest was left as is

    // mov     rax, qword ptr [rbp - 136]
    // mov     qword ptr [rbp - 116], rax
    // mov     rax, qword ptr [rbp - 128]
    // mov     qword ptr [rbp - 108], rax
    // mov     eax, dword ptr [rbp - 120]
    // mov     dword ptr [rbp - 100], eax
    // vcvtsi2sd       xmm0, xmm0, dword ptr [rbp - 116]
    // lea     rdi, [rbp - 96]
    // call    example.DoCalculation.init
    // mov     rsi, qword ptr [rbp - 264]
    // mov     rax, qword ptr [rbp - 96]
    // mov     qword ptr [rbp - 88], rax
    // mov     rax, qword ptr [rbp - 88]
    // mov     qword ptr [rbp - 80], rax
    // vcvtsi2sd       xmm0, xmm0, dword ptr [rbp - 112]
    // lea     rdi, [rbp - 72]
    // lea     rdx, [rbp - 80]
    // call    example.DoCalculation.add
    // mov     rsi, qword ptr [rbp - 264]
    // mov     rax, qword ptr [rbp - 72]
    // mov     qword ptr [rbp - 64], rax
    // mov     rax, qword ptr [rbp - 64]
    // mov     qword ptr [rbp - 56], rax
    // vcvtsi2sd       xmm0, xmm0, dword ptr [rbp - 108]
    // lea     rdi, [rbp - 48]
    // lea     rdx, [rbp - 56]
    // call    example.DoCalculation.mul
    // mov     rsi, qword ptr [rbp - 264]
    // mov     rax, qword ptr [rbp - 48]
    // mov     qword ptr [rbp - 40], rax
    // mov     rax, qword ptr [rbp - 40]
    // mov     qword ptr [rbp - 32], rax
    // vcvtsi2sd       xmm0, xmm0, dword ptr [rbp - 104]
    // lea     rdi, [rbp - 24]
    // lea     rdx, [rbp - 32]
    // call    example.DoCalculation.div
    // lea     rax, [rbp - 24]
    // mov     qword ptr [rbp - 280], rax
    // jmp     .LBB3_6mov     rax, qword ptr [rbp - 136]
    // mov     qword ptr [rbp - 116], rax
    // mov     rax, qword ptr [rbp - 128]
    // mov     qword ptr [rbp - 108], rax
    // mov     eax, dword ptr [rbp - 120]
    // mov     dword ptr [rbp - 100], eaxmov     rax, qword ptr [rax]
    //  mov     qword ptr [rbp - 16], rax

    const inlined = inlinedFunction(input);

    // stop the timer

    print("comptime: {}\n", .{inlined.val});
}
