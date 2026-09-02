#![allow(long_running_const_eval)]

use std::fs::{File, OpenOptions};
use std::io::Write;
use std::time::Instant;
use trig_const::{cos, sin};
mod utils;

const fn generate_lut<const STEPS: usize>() -> [f64; STEPS] {
    // init with all 0's
    let mut arr = [0.0; STEPS];

    let mut i = 0;

    // no compile-time for loops, you have to use a while loop
    while i < STEPS {
        // const result: f64 = @as(f64, @floatFromInt(i)) * increment;

        let result = (i as f64) * utils::INCREMENT;

        arr[i] = cos(result) + sin(result);
        i += 1;
    }

    arr
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut perf_ctl = OpenOptions::new().write(true).open("/tmp/perf.ctl")?;
    let mut perf_ack = OpenOptions::new().read(true).open("/tmp/perf.ack")?;

    let test_cases: [f64; utils::TEST_SIZE] =
        utils::read_array_from_file::<{ utils::TEST_SIZE }>("lookup.txt");

    // force to be placed on the stack, so that it
    // has better cache locality using let
    static my_lut: [f64; utils::STEPS] = generate_lut::<{ utils::STEPS }>();

    // faster but not fair
    // let my_lut = std::hint::black_box(COMPTIME_LUT);

    let prediv = 1.0 / utils::INCREMENT;
    let mut warmup_sum: f64 = 0.0;
    let mut sum: f64 = 0.0;
    const ITERS: usize = 100;

    for _ in 0..ITERS {
        for &num in test_cases.iter() {
            let idx = std::hint::black_box((num * prediv) as usize);
            warmup_sum += my_lut[idx];
        }
    }

    std::hint::black_box(warmup_sum);

    utils::send_perf_cmd(&mut perf_ctl, &mut perf_ack, "enable")?;
    let start_time = Instant::now();

    /*
    Rust's noalias Guarantee: Because Rust's reference type system (& vs &mut) guarantees at compile time that an immutable slice (&[f64]) can never be mutated by anything else in the thread, rustc emits the noalias LLVM attribute automatically. LLVM reads this metadata, proves Loop Invariant Code Motion (LICM) is 100% mathematically safe, and hoists the memory reads out of the outer loop without any manual annotations.
    */

    for _ in 0..ITERS {
        for &num in test_cases.iter() {
            let idx = std::hint::black_box((num * prediv) as usize);
            sum += my_lut[idx];
        }
    }

    std::hint::black_box(sum);

    let end_time = Instant::now();
    utils::send_perf_cmd(&mut perf_ctl, &mut perf_ack, "disable")?;

    let duration = end_time.duration_since(start_time).as_nanos();

    println!(
        "Processed in: [{}] ns, sum: {}, warmup sum: {}",
        duration, sum, warmup_sum
    );

    Ok(())
}
