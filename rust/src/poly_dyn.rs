use std::fs::OpenOptions;
use std::hint::black_box;
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

    const SIZE: usize = 500;
    const ITERS: usize = 1000;

    let mut sound_outputs: [SoundEnum; SIZE * ITERS] = [SoundEnum::Woof; SIZE * ITERS];
    let mut sound_outputs_warmup: [SoundEnum; SIZE * ITERS] = [SoundEnum::Woof; SIZE * ITERS];

    // Single stack instances
    let dog = Dog::new();
    let cat = Cat::new();
    let mouse = Mouse::new();

    let mut zoo: [&dyn Animal; SIZE] = [&dog; SIZE];

    // Load animal array from file
    let input_arr: [i32; SIZE] = utils::read_array_from_file::<i32, SIZE>("animals.txt")?;

    for i in 0..SIZE {
        zoo[i] = match input_arr[i] {
            1 => &dog as &dyn Animal,
            2 => &cat as &dyn Animal,
            3 => &mouse as &dyn Animal,
            _ => unreachable!(),
        };
    }

    zoo = black_box(zoo);

    let mut ind: usize = 0;

    // 1. ----------- WARMUP -------------
    for _ in 0..ITERS {
        for animal in zoo.iter() {
            sound_outputs_warmup[ind] = animal.sound();
            ind += 1;
        }
    }

    ind = 0;

    zoo = black_box(zoo);

    // start perf, then the clock
    utils::send_perf_cmd(&mut perf_ctl, &mut perf_ack, "enable")?;
    let start_time = Instant::now();

    // 2. ----------- BENCHMARK -------------
    for _ in 0..ITERS {
        for animal in zoo.iter() {
            sound_outputs[ind] = animal.sound();
            ind += 1;
        }
    }

    // end the clock, then stop perf
    let end_time = Instant::now();
    utils::send_perf_cmd(&mut perf_ctl, &mut perf_ack, "disable")?;

    println!("\n---  VERIFYING OUTPUTS ---");
    for (i, res) in sound_outputs.iter().enumerate() {
        println!("Index {}: {:?}", i, res);
    }

    for (i, res) in sound_outputs_warmup.iter().enumerate() {
        println!("Index {}, sound_warmup: {:?}", i, res);
    }

    let duration = end_time.duration_since(start_time).as_nanos();
    println!("Processed in: [{}] ns", duration);

    black_box(sound_outputs);

    Ok(())
}
