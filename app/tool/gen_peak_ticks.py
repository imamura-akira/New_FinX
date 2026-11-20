#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 P-01 欢迎页趋势线高点"滴"声 assets/sounds/peak_1.wav … peak_5.wav（design/theme.md 第 7 节）。

纯脚本合成，不使用任何外部音频素材：每声约 100 ms，正弦基音 + 少量二次谐波与钟声式非谐波泛音，
2 ms 起音、快速指数衰减；5 个高点音调依次升高（C6、E6、G6、A6、C7，大调五声音阶上行），峰值约 -16 dBFS。
只用 Python 标准库；重新生成：python3 tool/gen_peak_ticks.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44100
DURATION = 0.10
PEAK_DBFS = -16.0
PITCHES = [1046.50, 1318.51, 1567.98, 1760.00, 2093.00]  # C6 E6 G6 A6 C7
PARTIALS = [(1.0, 1.0, 0.040), (2.0, 0.20, 0.022), (2.76, 0.08, 0.015)]  # (倍频, 相对幅度, 衰减时间常数 s)


def sample(freq: float, t: float) -> float:
    attack = min(1.0, t / 0.002)
    v = sum(amp * math.exp(-t / tau) * math.sin(2 * math.pi * freq * mult * t) for mult, amp, tau in PARTIALS)
    tail = DURATION - t
    if tail < 0.015:  # 结尾 15 ms 淡出，避免爆音
        v *= max(0.0, tail / 0.015)
    return attack * v


def main() -> None:
    out_dir = Path(__file__).resolve().parent.parent / 'assets' / 'sounds'
    out_dir.mkdir(parents=True, exist_ok=True)
    n = int(RATE * DURATION)
    for i, f in enumerate(PITCHES, 1):
        raw = [sample(f, k / RATE) for k in range(n)]
        gain = (10 ** (PEAK_DBFS / 20)) / (max(abs(x) for x in raw) or 1.0)
        out = out_dir / f'peak_{i}.wav'
        with wave.open(str(out), 'wb') as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(RATE)
            w.writeframes(b''.join(struct.pack('<h', int(round(x * gain * 32767))) for x in raw))
        print(f'wrote {out.name} ({f:.0f} Hz, {DURATION * 1000:.0f} ms)')


if __name__ == '__main__':
    main()
