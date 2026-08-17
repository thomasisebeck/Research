use std::time::Instant;
use std::fs::File;
use std::io::Write;
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
    let mut perf_ctl = File::create("/tmp/perf.ctl")?;

    let test_cases: [f64; utils::TEST_SIZE] = utils::read_array_from_file::<{ utils::TEST_SIZE }>("lookup.txt");

    // force to be placed on the stack, so that it
    // has better cache locality using let
    static COMPTIME_LUT: [f64; utils::STEPS] = generate_lut::<{ utils::STEPS }>();

    let my_lut = std::hint::black_box(COMPTIME_LUT);

    println!(
        "LUT size: {}, increment: {}, testSize: {}, degrees: {}, steps: {}\n",
        my_lut.len(),
        utils::INCREMENT,
        utils::TEST_SIZE,
        utils::DEGREES,
        utils::STEPS,
    );

    writeln!(perf_ctl, "enable")?;
    perf_ctl.flush()?;
    let start_time = Instant::now();

    let sum: f64 = test_cases
        .iter()
        .map(|&num| {
            let float_idx = (num as f64) / utils::INCREMENT;
            my_lut[float_idx as usize]
        })
        .sum();

    let end_time = Instant::now();
    writeln!(perf_ctl, "disable")?;
    perf_ctl.flush()?;

    let duration = end_time.duration_since(start_time).as_nanos();

    println!("Processed in: [{}] ns, sum: {}", duration, sum);

    Ok(())
}
