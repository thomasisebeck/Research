use std::time::Instant;

use libc::{PR_TASK_PERF_EVENTS_DISABLE, PR_TASK_PERF_EVENTS_ENABLE};

#[derive(Debug, Clone, Copy)]
enum SoundEnum {
    Woof,
    Meow,
    Squeek,
}

trait Animal {
    fn sound(&self) -> SoundEnum;
}

struct Dog {
    id: u64,
}

impl Dog {
    fn new() -> Self {
        Self { id: 1 }
    }
}
impl Animal for Dog {
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
}
impl Animal for Cat {
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
}
impl Animal for Mouse {
    fn sound(&self) -> SoundEnum {
        if self.id == 0 {
            SoundEnum::Woof
        } else {
            SoundEnum::Squeek
        }
    }
}

fn main() {
    const SIZE: usize = 21;
    const ITERS: usize = 100;

    let mut sound_outputs: [SoundEnum; SIZE * ITERS] = [SoundEnum::Woof; SIZE * ITERS];

    let (d1, d2, d3, d4, d5, d6, d7) = (
        Dog::new(),
        Dog::new(),
        Dog::new(),
        Dog::new(),
        Dog::new(),
        Dog::new(),
        Dog::new(),
    );
    let (c1, c2, c3, c4, c5, c6, c7) = (
        Cat::new(),
        Cat::new(),
        Cat::new(),
        Cat::new(),
        Cat::new(),
        Cat::new(),
        Cat::new(),
    );
    let (m1, m2, m3, m4, m5, m6, m7) = (
        Mouse::new(),
        Mouse::new(),
        Mouse::new(),
        Mouse::new(),
        Mouse::new(),
        Mouse::new(),
        Mouse::new(),
    );

    // 2. Populate array with trait object references (Zero heap!)
    let zoo: [&dyn Animal; SIZE] = [
        &d1, &c1, &m1, &c2, &d2, &m2, &d3, &m3, &c3, &m4, &c4, &d4, &m5, &d5, &c5, &m6, &d6, &c6,
        &m7, &c7, &d7,
    ];
    let zoo = std::hint::black_box(zoo);

    // using an unsafe block so that it's consistent with the cpp
    unsafe {
        libc::prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    }
    let start_time = Instant::now();

    let mut ind: usize = 0;

    //16700
    for _ in 0..ITERS {
        // Loop over dynamic coll
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
