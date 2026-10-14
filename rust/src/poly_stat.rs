use std::fs::File;
use std::io::Write;
use std::time::Instant;

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
    #[inline(always)]
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
    #[inline(always)]
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
    #[inline(always)]
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
    #[inline(always)]
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
    let mut perf_ctl = File::create("/tmp/perf.ctl")?;

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

    writeln!(perf_ctl, "enable")?;
    perf_ctl.flush()?;
    let start_time = Instant::now();

    zoo = std::hint::black_box(zoo);

    process_batch(&zoo, &mut sound_outputs, ITERS);

    let end_time = Instant::now();
    writeln!(perf_ctl, "disable")?;
    perf_ctl.flush()?;

    let duration = end_time.duration_since(start_time).as_nanos();

    println!("Processed in: [{}] ns", duration);

    println!("\n---  VERIFYING OUTPUTS ---");
    for (i, res) in sound_outputs.iter().enumerate() {
        println!("Index {}: {:?}", i, res);
    }

    std::hint::black_box(sound_outputs);

    Ok(())
}
