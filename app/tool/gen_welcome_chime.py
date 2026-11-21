#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 P-01 欢迎页提示音 assets/sounds/welcome_chime.wav（design/theme.md 第 7 节）。

纯脚本合成，不使用任何外部音频素材：C 大三和弦（C6–E6–G6）快速琶音，
每个音为正弦基音 + 少量泛音与钟声式非谐波泛音，指数衰减，约 0.7 秒，峰值约 -16 dBFS。
只用 Python 标准库；重新生成：python3 tool/gen_welcome_chime.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44100
DURATION = 0.72
PEAK_DBFS = -16.0
NOTES = [(1046.50, 0.00), (1318.51, 0.07), (1567.98, 0.14)]  # (频率 Hz, 起始秒)
PARTIALS = [(1.0, 1.0), (2.0, 0.18), (2.76, 0.06)]  # (倍频, 相对幅度)：基音、二次泛音、钟声非谐波


def sample(t: float) -> float:
    v = 0.0
    for freq, start in NOTES:
        dt = t - start
        if dt < 0:
            continue
        attack = min(1.0, dt / 0.006)  # 6 ms 起音，避免爆音
        env = attack * math.exp(-dt / 0.22)
        for mult, amp in PARTIALS:
            v += amp * env * math.sin(2 * math.pi * freq * mult * dt)
    tail = DURATION - t
    if tail < 0.08:  # 结尾 80 ms 淡出
        v *= max(0.0, tail / 0.08)
    return v


def main() -> None:
    n = int(RATE * DURATION)
    raw = [sample(i / RATE) for i in range(n)]
    peak = max(abs(x) for x in raw) or 1.0
    gain = (10 ** (PEAK_DBFS / 20)) / peak
    out = Path(__file__).resolve().parent.parent / 'assets' / 'sounds' / 'welcome_chime.wav'
    out.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(round(x * gain * 32767))) for x in raw))
    print(f'wrote {out} ({n / RATE:.2f}s, peak {PEAK_DBFS} dBFS)')


if __name__ == '__main__':
    main()
