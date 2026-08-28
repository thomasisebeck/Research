use std::fs;
use std::fs::File;
use std::io::{Read, Write, Result};
use std::fs::read_to_string;

#[derive(Clone, Copy)]
pub struct Colour {
    pub r: f32,
    pub g: f32,
    pub b: f32,
}

pub enum Mode {
    HIGH,
    MED,
    LOW,
}

include!(concat!(env!("OUT_DIR"), "/increment_config.rs"));

pub const IMAGE_SIZE: usize = 500;
pub const TEST_SIZE: usize = 500;
pub const DEGREES: f64 = 360.0;
pub const STEPS: usize = (DEGREES / INCREMENT) as usize;

pub trait PipelineConfig {
    const BLUR_MODE: Mode;
    const APPLY_BLUR: bool;
    const QUANTISE_MODE: Mode;
    const APPLY_QUANTISATION: bool;
    const SATURATION_MODE: Mode;
    const APPLY_SATURATION: bool;
}

pub struct HighQualityConfig;

impl PipelineConfig for HighQualityConfig {
    const BLUR_MODE: Mode = Mode::HIGH;
    const APPLY_BLUR: bool = true;
    const QUANTISE_MODE: Mode = Mode::HIGH;
    const APPLY_QUANTISATION: bool = true;
    const SATURATION_MODE: Mode = Mode::HIGH;
    const APPLY_SATURATION: bool = true;
}

pub struct MediumQualityConfig;

impl PipelineConfig for MediumQualityConfig {
    const BLUR_MODE: Mode = Mode::MED;
    const APPLY_BLUR: bool = true;
    const QUANTISE_MODE: Mode = Mode::MED;
    const APPLY_QUANTISATION: bool = true;
    const SATURATION_MODE: Mode = Mode::MED;
    const APPLY_SATURATION: bool = false;
}

pub struct LowQualityConfig;

impl PipelineConfig for LowQualityConfig {
    const BLUR_MODE: Mode = Mode::LOW;
    const APPLY_BLUR: bool = false;
    const QUANTISE_MODE: Mode = Mode::LOW;
    const APPLY_QUANTISATION: bool = false; 
    const SATURATION_MODE: Mode = Mode::LOW;
    const APPLY_SATURATION: bool = true;
}

#[derive(Clone, Copy)] // to copy out of the node
pub struct Neighbours {
    pub top_left: Colour,
    pub middle_left: Colour,
    pub bottom_left: Colour,
    pub bottom_middle: Colour,
    pub bottom_right: Colour,
    pub middle_right: Colour,
    pub top_right: Colour,
    pub top_middle: Colour,
}


pub fn send_perf_cmd(ctl: &mut File, ack: &mut File, cmd: &str) -> Result<()> {
    writeln!(ctl, "{}", cmd)?;
    ctl.flush()?;
    
    let mut ack_buf = [0u8; 4]; // "ack\n" is 4 bytes
    ack.read_exact(&mut ack_buf)?;
    
    Ok(())
}

pub fn read_array_from_file<const STEPS: usize>(path: &str) -> [f64; STEPS] {
    let mut my_arr: [f64; STEPS] = [0.0; STEPS];

    let mut counter = 0;

    for line in read_to_string(path).unwrap().lines() {

        if counter >= STEPS {
            break;
        }

        my_arr[counter] = line.parse::<f64>().unwrap();
        counter += 1;
    }

    assert!(counter == my_arr.len());

    my_arr
}

pub fn print_array<const Size: usize>(arr: &[i32; Size]) {
    print!("[ ");

    for n in 0..=(Size - 1) {
        print!("{} ", arr[n]);
    }

    print!("]\n");
}

pub fn read_image_from_file(path: &str, mat: &mut [[Colour; IMAGE_SIZE]; IMAGE_SIZE]) {
    let content = fs::read_to_string(path).expect("Cannot open file");

    // split by both spaces and newlines
    // will split the rgb values as well
    let mut tokens = content.split_whitespace();
    let mut counter = 0;

    for row in 0..IMAGE_SIZE {
        for col in 0..IMAGE_SIZE {
            // 3. Extract r, g, and b
            let r: f32 = tokens
                .next()
                .and_then(|t| t.parse().ok())
                .expect("File corrupted");

            let g: f32 = tokens
                .next()
                .and_then(|t| t.parse().ok())
                .expect("File corrupted");

            let b: f32 = tokens
                .next()
                .and_then(|t| t.parse().ok())
                .expect("File corrupted");

            // Put them in the matrix
            mat[row][col].r = r;
            mat[row][col].g = g;
            mat[row][col].b = b;

            counter += 1;
        }
    }
}
