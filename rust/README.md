To run another file:

go into the Cargo.toml

update the path!!!

eg:

```
[[bin]]
name = "lut"
path = "src/image_pipeline_comptime.rs"
```

run:

```
cargo build --release
cargo run
```
