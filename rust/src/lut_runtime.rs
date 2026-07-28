use libc::{PR_TASK_PERF_EVENTS_DISABLE, PR_TASK_PERF_EVENTS_ENABLE};
use std::time::Instant;
mod utils;

const INCREMENT: f64 = 0.01;
const TEST_SIZE: usize = 500;
const DEGREES: f64 = 360.0;
const STEPS: usize = (DEGREES / INCREMENT) as usize;

fn main() {
    let test_cases: [f64; TEST_SIZE] = utils::read_array_from_file::<TEST_SIZE>("lookup.txt");

    println!(
        "increment: {}, testSize: {}, degrees: {}, steps: {}\n",
        INCREMENT, TEST_SIZE, DEGREES, STEPS,
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
