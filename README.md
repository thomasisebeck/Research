# C++ Implementation

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
