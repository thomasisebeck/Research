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

// Generic batch processor constrained by Soundable
fn process_batch<T: Soundable>(animals: &[T], outputs: &mut [SoundEnum], iters: usize) {
    let mut ind = 0;

    // NOTE: 16 byte traversal
    for _ in 0..iters {
        /*
                .Ltmp35:
                mov     byte ptr [rsp + rbx + 504], dl
                .loc     5 132 13
                inc     rbx                      ;<--- 1. INCREMENTS OUTPUT INDEX (ind++)
        .Ltmp36:

                .file   7 "/rustc/..." "library/core/src/ptr/non_null.rs"
                .loc     7 1714 9
                add     rcx, 16                  ;<--- 2. INCREMENTS SLICE/COLLECTION POINTER
        .Ltmp37:
                cmp     rcx, 344                 ;<--- 3. CHECKS LOOP TERMINATION CONDITION

                */
        for animal in animals.iter() {
            /*
                        .Ltmp34:
            .LBB4_7:
                    .loc    5 103 13 is_stmt 1
                    cmp     rbx, 2099
                    ja      .LBB4_9
            .Ltmp35:
                    mov     byte ptr [rsp + rbx + 504], dl
                    .loc    5 104 13
                    inc     rbx

                       lea     rdx, [rip + .Lanon.123894f5ed6fe0035d712c40ba974041.1]
                    mov     esi, 2100

                    mov     rdi, rbx
                    call    qword ptr [rip + core[940e698046960fd5]::panicking::panic_bounds_check@GOTPCREL]
                        */

            outputs[ind] = animal.sound();
            ind += 1;
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
