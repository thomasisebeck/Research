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
