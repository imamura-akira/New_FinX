#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""F22-g：为欢迎页深色模式生成透明底素材（原图为 RGB 白底，深色下会出现白色方块）。

  assets/brand/logo.png      → assets/brand/logo_dark.png       （颜色转透明：白色 → 透明，彩色字标与手写体保留抗锯齿）
  assets/brand/fifi_pill.png → assets/brand/fifi_pill_dark.png  （从四边泛洪去除外部近白背景；猫与胶囊内部不动）

原图不修改（浅色模式继续使用原图）。只用 Python 标准库；重新生成：python3 tool/gen_welcome_dark_assets.py
加 --preview 时另输出合成到深色底（#141220）的预览图到 build/（不入库）。
"""
import struct
import sys
import zlib
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
BG_DARK = (0x14, 0x12, 0x20)


def read_png(path):
    data = path.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    i, idat, w = 8, b'', None
    while i < len(data):
        ln = struct.unpack('>I', data[i:i + 4])[0]
        t, body = data[i + 4:i + 8], data[i + 8:i + 8 + ln]
        if t == b'IHDR':
            w, h, bd, ct, _, _, il = struct.unpack('>IIBBBBB', body)
            assert bd == 8 and il == 0 and ct in (2, 6), (bd, ct, il)
        elif t == b'IDAT':
            idat += body
        i += 12 + ln
    bpp = 3 if ct == 2 else 4
    raw, stride = zlib.decompress(idat), w * bpp
    rows, prev, p = [], bytearray(stride), 0
    for _ in range(h):
        f, line = raw[p], bytearray(raw[p + 1:p + 1 + stride])
        p += 1 + stride
        for x in range(stride):
            a = line[x - bpp] if x >= bpp else 0
            b = prev[x]
            c = prev[x - bpp] if x >= bpp else 0
            if f == 1:
                line[x] = (line[x] + a) & 255
            elif f == 2:
                line[x] = (line[x] + b) & 255
            elif f == 3:
                line[x] = (line[x] + (a + b) // 2) & 255
            elif f == 4:
                pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
                line[x] = (line[x] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        rows.append(line)
        prev = line
    px = [[tuple(r[x * bpp:x * bpp + 3]) + ((r[x * bpp + 3],) if bpp == 4 else (255,)) for x in range(w)] for r in rows]
    return w, h, px


def write_png(path, w, h, px):
    raw = b''.join(b'\x00' + bytes(v for p in row for v in p) for row in px)
    chunk = lambda t, b: struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b) & 0xffffffff)
    path.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def color_to_alpha(px):
    """白色 → 透明（GIMP color-to-alpha 的白色特例）。"""
    out = []
    for row in px:
        o = []
        for r, g, b, _ in row:
            a = max(255 - r, 255 - g, 255 - b) / 255
            if a < 0.05:
                o.append((0, 0, 0, 0))
                continue
            f = lambda c: max(0, min(255, round((c - 255 * (1 - a)) / a)))
            o.append((f(r), f(g), f(b), round(a * 255)))
        out.append(o)
    return out


def flood_clear(w, h, px, thr=236, soft=214):
    """从四边泛洪去除近白背景（4 邻接，所有通道 ≥ thr）；与背景相邻的较亮像素按亮度给半透明，边缘柔和。"""
    near = lambda p: min(p[:3]) >= thr
    bg = [[False] * w for _ in range(h)]
    q = deque((x, y) for x in range(w) for y in (0, h - 1)) + deque((x, y) for y in range(h) for x in (0, w - 1))
    while q:
        x, y = q.popleft()
        if bg[y][x] or not near(px[y][x]):
            continue
        bg[y][x] = True
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < w and 0 <= ny < h and not bg[ny][nx]:
                q.append((nx, ny))
    out = [list(row) for row in px]
    for y in range(h):
        for x in range(w):
            r, g, b, _ = px[y][x]
            if bg[y][x]:
                out[y][x] = (0, 0, 0, 0)
            elif min(r, g, b) >= soft and any(0 <= x + dx < w and 0 <= y + dy < h and bg[y + dy][x + dx] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                a = (255 - min(r, g, b)) / (255 - soft)
                out[y][x] = (r, g, b, max(0, min(255, round(a * 255))))
    return out


def preview(w, h, px, path):
    comp = [[tuple(round(c * a / 255 + bgc * (1 - a / 255)) for c, bgc in zip(p[:3], BG_DARK)) + (255,) for p in row for a in (p[3],)] for row in px]
    write_png(path, w, h, comp)


def main():
    jobs = [('logo', color_to_alpha), ('fifi_pill', None)]
    for name, fn in jobs:
        w, h, px = read_png(ROOT / 'assets' / 'brand' / f'{name}.png')
        out = fn(px) if fn else flood_clear(w, h, px)
        dst = ROOT / 'assets' / 'brand' / f'{name}_dark.png'
        write_png(dst, w, h, out)
        print('wrote', dst.relative_to(ROOT))
        if '--preview' in sys.argv:
            (ROOT / 'build').mkdir(exist_ok=True)
            preview(w, h, out, ROOT / 'build' / f'{name}_dark_preview.png')


if __name__ == '__main__':
    main()
