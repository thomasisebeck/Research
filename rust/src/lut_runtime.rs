use std::fs::{File, OpenOptions};
use std::io::Write;
use std::time::Instant;
mod utils;

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut perf_ctl = OpenOptions::new().write(true).open("/tmp/perf.ctl")?;
    let mut perf_ack = OpenOptions::new().read(true).open("/tmp/perf.ack")?;

    let test_cases: [f64; utils::TEST_SIZE] =
        utils::read_array_from_file::<{ utils::TEST_SIZE }>("lookup.txt");

    println!(
        "increment: {}, testSize: {}, degrees: {}, steps: {}\n",
        utils::INCREMENT,
        utils::TEST_SIZE,
        utils::DEGREES,
        utils::STEPS,
    );

    let mut sum: f64 = 0.0;

    utils::send_perf_cmd(&mut perf_ctl, &mut perf_ack, "enable")?;
    let start_time = Instant::now();

    for num in test_cases {
        sum += num.cos() + num.sin();
    }

    let end_time = Instant::now();
    utils::send_perf_cmd(&mut perf_ctl, &mut perf_ack, "disable")?;

    let duration = end_time.duration_since(start_time).as_nanos();

    println!("Processed in: [{}] ns, sum: {}", duration, sum);

    Ok(())
}
