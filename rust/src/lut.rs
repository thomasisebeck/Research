use std::time::Instant;

use trig_const::{cos, sin};
mod utils;

// use rand::prelude::*;

const INCREMENT: f64 = 0.01;
const TEST_SIZE: usize = 500;
const DEGREES: f64 = 360.0;
const STEPS: usize = (DEGREES / INCREMENT) as usize;

const fn generate_lut<const STEPS: usize>() -> [f64; STEPS] {
    // init with all 0's
    let mut arr = [0.0; STEPS];

    let mut i = 0;

    // no compile-time for loops, you have to use a while loop
    while i < STEPS {
        // const result: f64 = @as(f64, @floatFromInt(i)) * increment;

        let result = (i as f64) * INCREMENT;

        arr[i] = cos(result) + sin(result);
        i += 1;
    }

    arr
}

fn main() {
    let test_cases: [f64; TEST_SIZE] = utils::read_array_from_file::<TEST_SIZE>("lookup.txt");

    // println!("This is the array read from the file:");
    // utils::print_array::<TEST_SIZE>(&test_cases);

    // force to be placed on the stack, so that it
    // has better cache locality using let
    let MY_LUT: [f64; STEPS] = generate_lut();

    println!(
        "LUT size: {}, increment: {}, testSize: {}, degrees: {}, steps: {}\n",
        MY_LUT.len(),
        INCREMENT,
        TEST_SIZE,
        DEGREES,
        STEPS,
    );

    // let mut sum_comp: f64 = 0.0;

    let mut start_time = Instant::now();

    /*
    for (test_cases) |num| {
        const float_idx = @as(f64, @floatFromInt(num)) / increment;

        sum_comp += myLut[@intFromFloat(float_idx)];
    }
    */

    let sum_comp: f64 = test_cases
        .iter()
        .map(|&num| {
            let float_idx = (num as f64) / INCREMENT;
            MY_LUT[float_idx as usize]
        })
        .sum();

    /*for num in test_cases {
        let idx = (num / INCREMENT).round() as usize;
        sum_comp += MY_LUT[idx];
    }*/

    let duration_comp = start_time.elapsed();

    let mut sum_run: f64 = 0.0;

    start_time = Instant::now();

    for num in test_cases {
        sum_run += num.cos() + num.sin();
    }

    let duration_run = start_time.elapsed();

    println!("Runtime processed in: {} ns", duration_run.as_nanos());
    println!("Comptime processed in: {} ns", duration_comp.as_nanos());
    println!("Sum run: {}", sum_run);
    println!("Sum comp: {}", sum_comp);
}

/*

   var sum_comp: f64 = 0;

   const io = init.io;

   var start_time = std.Io.Clock.now(.awake, io);

   for (test_cases) |num| {
       //for (0..TEST_SIZE) |num| {
       // std.debug.print("input: {}, output: {}\n", .{ num, myLut[@intCast(num)] });
       sum_comp += myLut[@intCast(num)];
   }

   var end_time = std.Io.Clock.now(.awake, io);
   const duration_comp = start_time.durationTo(end_time);

   var sum_run: f64 = 0;

   start_time = std.Io.Clock.now(.awake, io);

   // dynamic
   for (test_cases) |num| {
       // for (0..TEST_SIZE) |num| {
       const float_num = @as(f64, @floatFromInt(num));
       const angle = float_num * @as(f64, increment);

       sum_run += @sin(angle) + @cos(angle);
   }

   end_time = std.Io.Clock.now(.awake, io);
   const duration_run = start_time.durationTo(end_time);
   print("Runtime processed in: {} ns\n", .{duration_run.toNanoseconds()});
   print("Comptime processed in: {} ns\n", .{duration_comp.toNanoseconds()});
   print("Sum comp: {d}\n", .{sum_comp});
   print("Sum run: {d}\n", .{sum_run});

*/
