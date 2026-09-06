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

    const SIZE: usize = 500;
    const ITERS: usize = 1000;

    let mut sound_outputs: [SoundEnum; SIZE * ITERS] = [SoundEnum::Woof; SIZE * ITERS];

    // Read from file and reference single stack instances
    let dog = Dog::new();
    let cat = Cat::new();
    let mouse = Mouse::new();

    let mut zoo: [Animal; SIZE] = [Animal::Dog(&dog); SIZE];
    let input_arr: [i32; SIZE] = utils::read_array_from_file::<i32, SIZE>("animals.txt")?;

    for i in 0..SIZE {
        zoo[i] = match input_arr[i] {
            1 => Animal::Dog(&dog),
            2 => Animal::Cat(&cat),
            3 => Animal::Mouse(&mouse),
            _ => unreachable!(),
        };
    }

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
