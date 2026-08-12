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

#[derive(Clone, Copy)]
enum AnimalRef<'a> {
    Dog(&'a Dog),
    Cat(&'a Cat),
    Mouse(&'a Mouse),
}

impl<'a> AnimalRef<'a> {
    fn sound(&self) -> SoundEnum {
        match self {
            AnimalRef::Dog(d) => d.sound(),

            AnimalRef::Cat(c) => c.sound(),

            AnimalRef::Mouse(m) => m.sound(),
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

    // 2. Build the array pointing to those stack-allocated variables
    let zoo: [AnimalRef; SIZE] = [
        AnimalRef::Dog(&d1),
        AnimalRef::Cat(&c1),
        AnimalRef::Mouse(&m1),
        AnimalRef::Cat(&c2),
        AnimalRef::Dog(&d2),
        AnimalRef::Mouse(&m2),
        AnimalRef::Dog(&d3),
        AnimalRef::Mouse(&m3),
        AnimalRef::Cat(&c3),
        AnimalRef::Mouse(&m4),
        AnimalRef::Cat(&c4),
        AnimalRef::Dog(&d4),
        AnimalRef::Mouse(&m5),
        AnimalRef::Dog(&d5),
        AnimalRef::Cat(&c5),
        AnimalRef::Mouse(&m6),
        AnimalRef::Dog(&d6),
        AnimalRef::Cat(&c6),
        AnimalRef::Mouse(&m7),
        AnimalRef::Cat(&c7),
        AnimalRef::Dog(&d7),
    ];

    // using an unsafe block so that it's consistent with the cpp
    unsafe {
        libc::prctl(PR_TASK_PERF_EVENTS_ENABLE, 0, 0, 0, 0);
    }
    let start_time = Instant::now();

    let mut ind: usize = 0;

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
