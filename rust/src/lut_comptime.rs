use std::time::Instant;

use libc::{PR_TASK_PERF_EVENTS_DISABLE, PR_TASK_PERF_EVENTS_ENABLE};

use trig_const::{cos, sin};
mod utils;

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

    unsafe {
        libc::prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    }
    let start_time = Instant::now();

    let sum: f64 = test_cases
        .iter()
        .map(|&num| {
            let float_idx = (num as f64) / INCREMENT;
            MY_LUT[float_idx as usize]
        })
        .sum();

    let end_time = Instant::now();
    unsafe {
        libc::prctl(PR_TASK_PERF_EVENTS_DISABLE, 0, 0, 0, 0);
    }

    let duration = end_time.duration_since(start_time).as_nanos();

    println!("Processed in: {} ns", duration);
    println!("Sum: {}", sum);
}
