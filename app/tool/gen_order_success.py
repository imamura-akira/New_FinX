#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 F22-c 成交成功提示音 assets/sounds/order_success.wav（design/theme.md 第 7 节）。

纯脚本合成，不使用任何外部音频素材：C6–E6–G6–C7 上行琶音（每音 70 ms 间隔，钟声式短衰减），总长约 0.7 秒，
比"开启上线提醒"的单声叮更有庆祝感；峰值约 -16 dBFS。只用 Python 标准库；重新生成：python3 tool/gen_order_success.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44100
DURATION = 0.70
PEAK_DBFS = -16.0
NOTES = [(0.00, 1046.5), (0.07, 1318.5), (0.14, 1568.0), (0.21, 2093.0)]  # (起始 s, 频率 Hz)
PARTIALS = [(1.0, 1.0, 0.16), (2.0, 0.18, 0.07), (3.01, 0.06, 0.04)]


def note(t: float, f: float) -> float:
    if t < 0:
        return 0.0
    attack = min(1.0, t / 0.003)
    return attack * sum(a * math.exp(-t / tau) * math.sin(2 * math.pi * f * m * t) for m, a, tau in PARTIALS)


def sample(t: float) -> float:
    v = sum(note(t - s, f) * (0.8 + 0.1 * i) for i, (s, f) in enumerate(NOTES))
    tail = DURATION - t
    if tail < 0.08:
        v *= max(0.0, tail / 0.08)
    return v


def main() -> None:
    n = int(RATE * DURATION)
    raw = [sample(i / RATE) for i in range(n)]
    peak = max(abs(x) for x in raw) or 1.0
    gain = (10 ** (PEAK_DBFS / 20)) / peak
    out = Path(__file__).resolve().parent.parent / 'assets' / 'sounds' / 'order_success.wav'
    with wave.open(str(out), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(round(x * gain * 32767))) for x in raw))
    print(f'wrote {out} ({n / RATE:.2f}s, peak {PEAK_DBFS} dBFS)')


if __name__ == '__main__':
    main()
