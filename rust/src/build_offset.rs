mod utils;
use std::{fs::OpenOptions, time::Instant};

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut perf_ctl = OpenOptions::new().write(true).open("/tmp/perf.ctl")?;
    let mut perf_ack = OpenOptions::new().read(true).open("/tmp/perf.ack")?;

    // --------------- start perf, then the clock ---------------- //
    utils::send_perf_cmd(&mut perf_ctl, &mut perf_ack, "enable")?;
    let start_time = Instant::now();
    // ----------------------------------------------------------- //

    // Measured payload
    println!("Hello, World!");

    // -------------- stop the clock, then end perf -------------- //
    let end_time = Instant::now();
    utils::send_perf_cmd(&mut perf_ctl, &mut perf_ack, "disable")?;
    // ----------------------------------------------------------- //

    let duration = end_time.duration_since(start_time).as_nanos();

    println!("Processed in: [{}] ns", duration);

    Ok(())
}
