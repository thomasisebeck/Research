use std::time::Instant;

use libc::{PR_TASK_PERF_EVENTS_DISABLE, PR_TASK_PERF_EVENTS_ENABLE};

#[derive(Debug, Clone, Copy)]
enum SoundEnum {
    Woof,
    Meow,
    Squeek,
}

struct Dog {
    id: u64,
}

impl Dog {
    fn new() -> Self {
        Self { id: 1 }
    }

    fn sound(&self) -> SoundEnum {
        if self.id == 0 {
            SoundEnum::Meow
        } else {
            SoundEnum::Woof
        }
    }
}

struct Cat {
    id: u64,
}

impl Cat {
    fn new() -> Self {
        Self { id: 1 }
    }

    fn sound(&self) -> SoundEnum {
        if self.id == 0 {
            SoundEnum::Woof
        } else {
            SoundEnum::Meow
        }
    }
}

struct Mouse {
    id: u64,
}
impl Mouse {
    fn new() -> Self {
        Self { id: 1 }
    }
    fn sound(&self) -> SoundEnum {
        if self.id == 0 {
            SoundEnum::Woof
        } else {
            SoundEnum::Squeek
        }
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
    const SIZE: usize = 21;
    const ITERS: usize = 100;

    let mut sound_outputs: [SoundEnum; SIZE * ITERS] = [SoundEnum::Woof; SIZE * ITERS];

    // static = point to static instance
    let zoo: [Animal; SIZE] = [
        Animal::Dog(Dog::new()),
        Animal::Cat(Cat::new()),
        Animal::Mouse(Mouse::new()),
        Animal::Cat(Cat::new()),
        Animal::Dog(Dog::new()),
        Animal::Mouse(Mouse::new()),
        Animal::Dog(Dog::new()),
        Animal::Mouse(Mouse::new()),
        Animal::Cat(Cat::new()),
        Animal::Mouse(Mouse::new()),
        Animal::Cat(Cat::new()),
        Animal::Dog(Dog::new()),
        Animal::Mouse(Mouse::new()),
        Animal::Dog(Dog::new()),
        Animal::Cat(Cat::new()),
        Animal::Mouse(Mouse::new()),
        Animal::Dog(Dog::new()),
        Animal::Cat(Cat::new()),
        Animal::Mouse(Mouse::new()),
        Animal::Cat(Cat::new()),
        Animal::Dog(Dog::new()),
    ];
    let zoo = std::hint::black_box(zoo);

    // using an unsafe block so that it's consistent with the cpp
    unsafe {
        libc::prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    }
    let start_time = Instant::now();

    let mut ind: usize = 0;

    for _ in 0..ITERS {
        for animal in zoo.iter() {
            sound_outputs[ind] = animal.sound();
            ind += 1;
        }
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
