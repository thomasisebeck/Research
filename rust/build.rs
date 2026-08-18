use std::env;
use std::fs;
use std::path::Path;

fn main() {
    // 1. Re-run this build script if INCREMENT_VAL changes
    println!("cargo:rerun-if-env-changed=INCREMENT_VAL");

    // 2. Read and parse INCREMENT_VAL with default fallback
    let raw_val = env::var("INCREMENT_VAL").unwrap_or_else(|_| "1.0".to_string());
    let val: f64 = raw_val.parse().expect("Invalid float for INCREMENT_VAL");

    // 3. Format value as a float token (prevents integer syntax errors like "1")
    let float_str = if raw_val.contains('.') {
        format!("{}", val)
    } else {
        format!("{:.1}", val)
    };

    let code = format!("pub const INCREMENT: f64 = {:?};\n", val);

    // 4. Resolve Cargo's OUT_DIR and write generated config
    let out_dir = env::var("OUT_DIR").expect("OUT_DIR environment variable not set");
    let out_path = Path::new(&out_dir).join("increment_config.rs");

    fs::write(out_path, code).expect("Failed to write increment_config.rs");
}
