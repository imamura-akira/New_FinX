#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""生成 P-27 "开启上线提醒"提示音 assets/sounds/reminder_ding.wav（design/theme.md 第 7 节）。

纯脚本合成，不使用任何外部音频素材：单声"叮"，A6（1760 Hz）正弦基音 + 少量谐波与钟声式非谐波泛音，
3 ms 快速起音、短指数衰减，约 0.4 秒，比 P-01 欢迎和弦更短促明亮；峰值约 -16 dBFS。
只用 Python 标准库；重新生成：python3 tool/gen_reminder_ding.py
"""
import math
import struct
import wave
from pathlib import Path

RATE = 44100
DURATION = 0.40
PEAK_DBFS = -16.0
FREQ = 1760.0  # A6
PARTIALS = [(1.0, 1.0, 0.11), (2.0, 0.22, 0.06), (2.76, 0.10, 0.035), (5.40, 0.04, 0.02)]  # (倍频, 相对幅度, 衰减时间常数 s)


def sample(t: float) -> float:
    attack = min(1.0, t / 0.003)  # 3 ms 起音，避免爆音
    v = 0.0
    for mult, amp, tau in PARTIALS:
        v += amp * math.exp(-t / tau) * math.sin(2 * math.pi * FREQ * mult * t)
    v *= attack
    tail = DURATION - t
    if tail < 0.06:  # 结尾 60 ms 淡出
        v *= max(0.0, tail / 0.06)
    return v


def main() -> None:
    n = int(RATE * DURATION)
    raw = [sample(i / RATE) for i in range(n)]
    peak = max(abs(x) for x in raw) or 1.0
    gain = (10 ** (PEAK_DBFS / 20)) / peak
    out = Path(__file__).resolve().parent.parent / 'assets' / 'sounds' / 'reminder_ding.wav'
    out.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(out), 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(round(x * gain * 32767))) for x in raw))
    print(f'wrote {out} ({n / RATE:.2f}s, peak {PEAK_DBFS} dBFS)')


if __name__ == '__main__':
    main()
