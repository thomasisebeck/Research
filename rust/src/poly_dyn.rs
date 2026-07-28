use std::time::Instant;

use libc::{PR_TASK_PERF_EVENTS_DISABLE, PR_TASK_PERF_EVENTS_ENABLE};

#[derive(Debug, Clone, Copy)]
enum SoundEnum {
    Woof,
    Meow,
    Squeek,
}

trait AnimalTrait {
    fn sound(&self) -> SoundEnum;
}

struct Dog;
struct Cat;
struct Mouse;

impl AnimalTrait for Dog {
    fn sound(&self) -> SoundEnum {
        SoundEnum::Woof
    }
}

impl AnimalTrait for Cat {
    fn sound(&self) -> SoundEnum {
        SoundEnum::Meow
    }
}

impl AnimalTrait for Mouse {
    fn sound(&self) -> SoundEnum {
        SoundEnum::Squeek
    }
}

fn main() {
    const SIZE: usize = 3;
    let mut sound_outputs: [SoundEnum; SIZE] = [SoundEnum::Woof; SIZE];

    // Instantiate directly into the dynamic trait object container
    let zoo: Vec<Box<dyn AnimalTrait>> = vec![Box::new(Cat), Box::new(Dog), Box::new(Mouse)];

    // using an unsafe block so that it's consistent with the cpp
    unsafe {
        libc::prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    }
    let start_time = Instant::now();

    // Loop over dynamic coll
    for (i, animal) in zoo.iter().enumerate() {
        sound_outputs[i] = animal.sound();

        std::hint::black_box(sound_outputs[i]);
    }

    let duration = start_time.elapsed();
    unsafe {
        libc::prctl(PR_TASK_PERF_EVENTS_DISABLE, 0, 0, 0, 0);
    }

    println!("\n---  VERIFYING OUTPUTS ---");
    for (i, res) in sound_outputs.iter().enumerate() {
        println!("Index {}: {:?}", i, res);
    }
    println!("Processed in: {} ns", duration.as_nanos());
}
