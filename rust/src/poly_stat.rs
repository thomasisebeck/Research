use std::fs::{File, OpenOptions};
use std::io::Write;
use std::time::Instant;
mod utils;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
enum SoundEnum {
    Woof,
    Meow,
    Squeek,
}

// 1. Define the trait
trait Soundable {
    fn sound(&self) -> SoundEnum;
}

#[derive(Clone, Copy)]
struct Dog {
    id: u64,
}
impl Dog {
    fn new() -> Self {
        Self { id: 1 }
    }
}
// Implement Soundable for Dog
impl Soundable for Dog {
    fn sound(&self) -> SoundEnum {
        if self.id == 0 {
            SoundEnum::Meow
        } else {
            SoundEnum::Woof
        }
    }
}

#[derive(Clone, Copy)]
struct Cat {
    id: u64,
}
impl Cat {
    fn new() -> Self {
        Self { id: 1 }
    }
}
// Implement Soundable for Cat
impl Soundable for Cat {
    fn sound(&self) -> SoundEnum {
        if self.id == 0 {
            SoundEnum::Woof
        } else {
            SoundEnum::Meow
        }
    }
}

#[derive(Clone, Copy)]
struct Mouse {
    id: u64,
}
impl Mouse {
    fn new() -> Self {
        Self { id: 1 }
    }
}
// Implement Soundable for Mouse
impl Soundable for Mouse {
    fn sound(&self) -> SoundEnum {
        if self.id == 0 {
            SoundEnum::Woof
        } else {
            SoundEnum::Squeek
        }
    }
}

#[derive(Clone, Copy)]
enum Animal<'a> {
    Dog(&'a Dog),
    Cat(&'a Cat),
    Mouse(&'a Mouse),
}

// Implement Soundable for the Animal enum wrapper
impl<'a> Soundable for Animal<'a> {
    fn sound(&self) -> SoundEnum {
        match self {
            Animal::Dog(d) => d.sound(),
            Animal::Cat(c) => c.sound(),
            Animal::Mouse(m) => m.sound(),
        }
    }
}

fn main() -> Result<(), Box<dyn std::error::Error>> {
    let mut perf_ctl = OpenOptions::new().write(true).open("/tmp/perf.ctl")?;
    let mut perf_ack = OpenOptions::new().read(true).open("/tmp/perf.ack")?;

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

    let mut zoo: [Animal; SIZE] = [
        Animal::Dog(&d1),
        Animal::Cat(&c1),
        Animal::Mouse(&m1),
        Animal::Cat(&c2),
        Animal::Dog(&d2),
        Animal::Mouse(&m2),
        Animal::Dog(&d3),
        Animal::Mouse(&m3),
        Animal::Cat(&c3),
        Animal::Mouse(&m4),
        Animal::Cat(&c4),
        Animal::Dog(&d4),
        Animal::Mouse(&m5),
        Animal::Dog(&d5),
        Animal::Cat(&c5),
        Animal::Mouse(&m6),
        Animal::Dog(&d6),
        Animal::Cat(&c6),
        Animal::Mouse(&m7),
        Animal::Cat(&c7),
        Animal::Dog(&d7),
    ];

    // prevents entire loop from being eval at comptime
    zoo = std::hint::black_box(zoo);

    let mut ind: usize = 0;

    utils::send_perf_cmd(&mut perf_ctl, &mut perf_ack, "enable")?;
    let start_time = Instant::now();

    for _ in 0..ITERS {
        // Loop over the fixed-size array directly
        for animal in zoo.iter() {
            sound_outputs[ind] = animal.sound();
            ind += 1;
        }
    }

    let end_time = Instant::now();
    utils::send_perf_cmd(&mut perf_ctl, &mut perf_ack, "disable")?;

    let duration = end_time.duration_since(start_time).as_nanos();

    println!("Processed in: [{}] ns", duration);

    println!("\n---  VERIFYING OUTPUTS ---");
    for (i, res) in sound_outputs.iter().enumerate() {
        println!("Index {}: {:?}", i, res);
    }

    // black box sound outputs after
    std::hint::black_box(sound_outputs);

    Ok(())
}
