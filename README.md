# LUT

rust beat the others because of hardware guarantees and aliasing
c++ and zig need the \_\_restrict stuff to promise to the compiler that the memory aliasing is turned off

# C++ Implementation

DONE:

- cpp:
  - calibration

update

```
sudo apt update && sudo apt install linux-tools-common linux-tools-generic linux-tools-$(uname -r)
```

unlock counters:

```
sudo sysctl -w kernel.perf_event_paranoid=-1
```

how to run:

```
perf stat -e branch-misses --delay=-1 ./out
```

timer:

```
sudo pacman -S time
```

get perf to work:

```
sudo su -
echo 0 > /proc/sys/kernel/perf_event_paranoid
exit
```
