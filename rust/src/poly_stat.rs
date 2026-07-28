use std::time::Instant;

use libc::{PR_TASK_PERF_EVENTS_DISABLE, PR_TASK_PERF_EVENTS_ENABLE};

#[derive(Debug, Clone, Copy)]
enum SoundEnum {
    Woof,
    Meow,
    Squeek,
}

struct Dog;
impl Dog {
    fn sound(&self) -> SoundEnum {
        SoundEnum::Woof
    }
}

struct Cat;
impl Cat {
    fn sound(&self) -> SoundEnum {
        SoundEnum::Meow
    }
}

struct Mouse;
impl Mouse {
    fn sound(&self) -> SoundEnum {
        SoundEnum::Squeek
    }
}

enum Animal {
    Cat(Cat),
    Dog(Dog),
    Mouse(Mouse),
}

impl Animal {
    fn sound(&self) -> SoundEnum {
        match self {
            Animal::Cat(c) => c.sound(),
            Animal::Dog(d) => d.sound(),
            Animal::Mouse(m) => m.sound(),
        }
    }
}

fn main() {
    const SIZE: usize = 3;
    let mut sound_outputs: [SoundEnum; SIZE] = [SoundEnum::Woof; SIZE];

    let zoo: [Animal; SIZE] = [Animal::Cat(Cat), Animal::Dog(Dog), Animal::Mouse(Mouse)];

    // using an unsafe block so that it's consistent with the cpp
    unsafe {
        libc::prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    }
    let start_time = Instant::now();

    for (i, animal) in zoo.iter().enumerate() {
        sound_outputs[i] = animal.sound();
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
