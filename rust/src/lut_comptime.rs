use std::time::Instant;

use libc::{PR_TASK_PERF_EVENTS_DISABLE, PR_TASK_PERF_EVENTS_ENABLE};

use trig_const::{cos, sin};
mod utils;


const fn generate_lut<const utils::STEPS: usize>() -> [f64; utils::STEPS] {
    // init with all 0's
    let mut arr = [0.0; utils::STEPS];

    let mut i = 0;

    // no compile-time for loops, you have to use a while loop
    while i < utils::STEPS {
        // const result: f64 = @as(f64, @floatFromInt(i)) * increment;

        let result = (i as f64) * INCREMENT;

        arr[i] = cos(result) + sin(result);
        i += 1;
    }

    arr
}

fn main() {
    let test_cases: [f64; utils::TEST_SIZE] = utils::read_array_from_file::<utils::TEST_SIZE>("lookup.txt");

    // force to be placed on the stack, so that it
    // has better cache locality using let
    static COMPTIME_LUT: [f64; utils::STEPS] = generate_lut();

    let my_lut = std::hint::black_box(COMPTIME_LUT);

    println!(
        "LUT size: {}, increment: {}, testSize: {}, degrees: {}, steps: {}\n",
        my_lut.len(),
        utils::INCREMENT,
        utils::TEST_SIZE,
        utils::DEGREES,
        utils::STEPS,
    );

    unsafe {
        libc::prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    }
    let start_time = Instant::now();

    let sum: f64 = test_cases
        .iter()
        .map(|&num| {
            let float_idx = (num as f64) / utils::INCREMENT;
            my_lut[float_idx as usize]
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
