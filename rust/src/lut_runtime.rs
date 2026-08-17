use std::time::Instant;
use std::fs::File;
use std::io::Write;
mod utils;


fn main()-> Result<(), Box<dyn std::error::Error>> {
    let mut perf_ctl = File::create("/tmp/perf.ctl")?;

    let test_cases: [f64; utils::TEST_SIZE] = utils::read_array_from_file::<{ utils::TEST_SIZE }>("lookup.txt");

    println!(
        "increment: {}, testSize: {}, degrees: {}, steps: {}\n",
        utils::INCREMENT, utils::TEST_SIZE, utils::DEGREES, utils::STEPS,
    );

    let mut sum: f64 = 0.0;

    writeln!(perf_ctl, "enable")?;
    perf_ctl.flush()?;
    let start_time = Instant::now();

    for num in test_cases {
        sum += num.cos() + num.sin();
    }

    let end_time = Instant::now();
    writeln!(perf_ctl, "disable")?;
    perf_ctl.flush()?;


    let duration = end_time.duration_since(start_time).as_nanos();

    println!("Processed in: [{}] ns, sum: {}", duration, sum);

    Ok(())
}
