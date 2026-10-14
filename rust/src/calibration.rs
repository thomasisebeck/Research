mod utils;
use std::arch::asm;
use std::{fs::OpenOptions, time::Instant};

#[inline(never)]
pub fn benchmark_loop(mut x: u64, iterations: u64) -> u64 {
    for _ in 0..iterations {
        x = x.wrapping_mul(6364136223846793005).wrapping_add(1);

        unsafe {
            asm!("# {0}", inout(reg) x, options(nomem, nostack, preserves_flags));
        }
    }
    x
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut perf_ctl = OpenOptions::new().write(true).open("/tmp/perf.ctl")?;
    let mut perf_ack = OpenOptions::new().read(true).open("/tmp/perf.ack")?;

    let ITERS = 100;
    let mut warmup_res = 0;
    let mut res = 0;

    let init_val = std::hint::black_box(200u64);
    let iters = std::hint::black_box(200u64);

    for _ in 0..ITERS {
        warmup_res += benchmark_loop(init_val, iters);
    }

    std::hint::black_box(warmup_res);

    // --------------- start perf, then the clock ---------------- //
    utils::send_perf_cmd(&mut perf_ctl, &mut perf_ack, "enable")?;
    let start_time = Instant::now();
    // ----------------------------------------------------------- //

    for _ in 0..ITERS {
        res += benchmark_loop(init_val, iters);
    }

    std::hint::black_box(res);

    // -------------- stop the clock, then end perf -------------- //
    let end_time = Instant::now();
    utils::send_perf_cmd(&mut perf_ctl, &mut perf_ack, "disable")?;
    // ----------------------------------------------------------- //
    //
    let duration = end_time.duration_since(start_time).as_nanos();

    println!(
        "Processed in: [{}] ns, warmup res {} res {}",
        duration, warmup_res, res
    );

    Ok(())
}
