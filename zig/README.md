Insall zig

debian:

```
sudo snap install --beta zig --classic
```

arch:

```
sudo pacman -S zig
```

run:

```
zig run file.zig -O ReleaseFast
```

setup perf:

```
mkfifo perf.ctl perf.ack
```
