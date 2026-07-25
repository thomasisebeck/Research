use trig_const::{cos, sin};

// use rand::prelude::*;

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
        let x = cos(i as f64) + sin(i as f64);
        arr[i] = x;
        i += 1;
    }

    arr
}

fn main() {
    static MY_LUT: [f64; STEPS] = generate_lut();

    for (i, item) in MY_LUT.iter().enumerate() {
        println!("index: {}, value: {}", i, item);
    }
}
