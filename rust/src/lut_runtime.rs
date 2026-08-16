use libc::{PR_TASK_PERF_EVENTS_DISABLE, PR_TASK_PERF_EVENTS_ENABLE};
use std::time::Instant;
mod utils;


fn main() {
    let test_cases: [f64; utils::TEST_SIZE] = utils::read_array_from_file::<utils::TEST_SIZE>("lookup.txt");

    println!(
        "increment: {}, testSize: {}, degrees: {}, steps: {}\n",
        utils::INCREMENT, utils::TEST_SIZE, utils::DEGREES, utils::STEPS,
    );

    let mut sum: f64 = 0.0;

    unsafe {
        libc::prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    }
    let start_time = Instant::now();

    for num in test_cases {
        sum += num.cos() + num.sin();
    }

    let end_time = Instant::now();
    unsafe {
        libc::prctl(PR_TASK_PERF_EVENTS_DISABLE, 0, 0, 0, 0);
    }

    let duration = end_time.duration_since(start_time).as_nanos();

    println!("Processed in: {} ns", duration);
    println!("Sum: {}", sum);
}
