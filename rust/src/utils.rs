use std::fs;
use std::fs::read_to_string;

pub const SIZE: usize = 50;

#[derive(Clone, Copy)]
pub struct Colour {
    pub r: f32,
    pub g: f32,
    pub b: f32,
}

pub fn read_array_from_file<const STEPS: usize>(path: &str) -> [f64; STEPS] {
    let mut my_arr: [f64; STEPS] = [0.0; STEPS];

    let mut counter = 0;

    for line in read_to_string(path).unwrap().lines() {
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

pub fn read_image_from_file(path: &str, mat: &mut [[Colour; SIZE]; SIZE]) {
    let content = fs::read_to_string(path).expect("Cannot open file");

    // split by both spaces and newlines
    // will split the rgb values as well
    let mut tokens = content.split_whitespace();
    let mut counter = 0;

    for row in 0..SIZE {
        for col in 0..SIZE {
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
