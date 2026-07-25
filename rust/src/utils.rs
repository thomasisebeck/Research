use std::fs::read_to_string;

pub fn read_array_from_file<const STEPS: usize>(path: &str) -> [i32; STEPS] {
    let mut my_arr: [i32; STEPS] = [0; STEPS];

    let mut counter = 0;

    for line in read_to_string(path).unwrap().lines() {
        my_arr[counter] = line.parse::<i32>().unwrap();
        counter += 1;
    }

    assert!(counter == my_arr.len());

    my_arr
}

pub fn print_array<const Size: usize>(arr: &[i32; Size]) {
    print!("[");

    for n in 0..=(Size - 1) {
        print!("{}", arr[n]);
    }

    print!("]\n");
}
