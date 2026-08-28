use std::fs::OpenOptions;
use std::time::Instant;
mod utils;

#[derive(Debug, Clone, Copy)]
#[repr(u8)]
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

    // 2. Populate array with trait object references (Zero heap!)
    let mut zoo: [&dyn Animal; SIZE] = [
        &d1 as &dyn Animal,
        &c1 as &dyn Animal,
        &m1 as &dyn Animal,
        &c2 as &dyn Animal,
        &d2 as &dyn Animal,
        &m2 as &dyn Animal,
        &d3 as &dyn Animal,
        &m3 as &dyn Animal,
        &c3 as &dyn Animal,
        &m4 as &dyn Animal,
        &c4 as &dyn Animal,
        &d4 as &dyn Animal,
        &m5 as &dyn Animal,
        &d5 as &dyn Animal,
        &c5 as &dyn Animal,
        &m6 as &dyn Animal,
        &d6 as &dyn Animal,
        &c6 as &dyn Animal,
        &m7 as &dyn Animal,
        &c7 as &dyn Animal,
        &d7 as &dyn Animal,
    ];

    // prevents entire loop from being eval at comptime
    zoo = std::hint::black_box(zoo);

    let mut ind: usize = 0;

    // start perf, then the timer
    utils::send_perf_cmd(&mut perf_ctl, &mut perf_ack, "enable")?;
    let start_time = Instant::now();

    //16700
    for _ in 0..ITERS {
        // Loop over dynamic coll
        for animal in zoo.iter() {
            sound_outputs[ind] = animal.sound();
            ind += 1;
        }
    }

    // end the timer, then end perf
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
