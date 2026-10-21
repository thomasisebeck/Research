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

    //  vmulsd  xmm0, xmm2, qword ptr [rcx + __anon_42197+80000]
    //  vcvttsd2si      rdx, xmm0
    //  mov     rsi, rdx
    //  sar     rsi, 63
    //  vsubsd  xmm0, xmm0, xmm3
    //  vcvttsd2si      rdi, xmm0
    //  and     rdi, rsi
    //  or      rdi, rdx
    //  vmulsd  xmm1, xmm2, qword ptr [rcx + __anon_42197+80008]
    //  vcvttsd2si      rdx, xmm1
    //  mov     rsi, rdx
    //  sar     rsi, 63
    //  vsubsd  xmm1, xmm1, xmm3
    //  vcvttsd2si      rdi, xmm1
    //  and     rdi, rsi
    //  or      rdi, rdx
    //  vmulsd  xmm1, xmm2, qword ptr [rcx + __anon_42197+80016]
    //  vcvttsd2si      rdx, xmm1
    //  mov     rsi, rdx
    //  sar     rsi, 63
    //  vsubsd  xmm1, xmm1, xmm3
    //  vcvttsd2si      rdi, xmm1
    //  and     rdi, rsi
    //  or      rdi, rdx
    //  vmulsd  xmm1, xmm2, qword ptr [rcx + __anon_42197+80024]
    //  vcvttsd2si      rdx, xmm1
    //  mov     rsi, rdx
    //  sar     rsi, 63
    //  vsubsd  xmm1, xmm1, xmm3
    //  vcvttsd2si      rdi, xmm1
    //  and     rdi, rsi
    //  or      rdi, rdx
    //  vmulsd  xmm1, xmm2, qword ptr [rcx + __anon_42197+80032]
    //  vcvttsd2si      rdx, xmm1
    //  mov     rsi, rdx
    //  sar     rsi, 63
    //  vsubsd  xmm1, xmm1, xmm3
    //  vcvttsd2si      rdi, xmm1
    //  and     rdi, rsi
    //  or      rdi, rdx
    //  vmulsd  xmm1, xmm2, qword ptr [rcx + __anon_42197+80040]
    //  vcvttsd2si      rdx, xmm1
    //  mov     rsi, rdx
    //  sar     rsi, 63
    //  vsubsd  xmm1, xmm1, xmm3
    //  vcvttsd2si      rdi, xmm1
    //  and     rdi, rsi
    //  or      rdi, rdx
    //  vmulsd  xmm1, xmm2, qword ptr [rcx + __anon_42197+80048]
    //  vcvttsd2si      rdx, xmm1
    //  mov     rsi, rdx
    //  sar     rsi, 63
    //  vsubsd  xmm1, xmm1, xmm3
    //  vcvttsd2si      rdi, xmm1
    //  and     rdi, rsi
    //  or      rdi, rdx
    //  vmulsd  xmm1, xmm2, qword ptr [rcx + __anon_42197+80056]
    //  vcvttsd2si      rdx, xmm1
    //  mov     rsi, rdx
    //  sar     rsi, 63
    //  vsubsd  xmm1, xmm1, xmm3
    //  vcvttsd2si      rdi, xmm1
    //  and     rdi, rsi
    //  or      rdi, rdx
    //  add     rcx, 64
    //  jne     .LBB1_381
