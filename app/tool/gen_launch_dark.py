#!/usr/bin/env python3
"""F21：由浅色启动图生成深色变体（仅用标准库）。

    python3 tool/gen_launch_dark.py

LaunchImage*.png 的浅薰衣草底（含爪印内部留白）按与底色的接近程度混合为深色背景 #141220，
渐变描边保持不变；输出 LaunchImageDark*.png，供 Contents.json 的 dark appearance 使用。
"""
import struct
import zlib
from pathlib import Path

DIR = Path(__file__).resolve().parent.parent / 'ios/Runner/Assets.xcassets/LaunchImage.imageset'
LIGHT = (246, 245, 252)  # #F6F5FC
DARK = (20, 18, 32)  # #141220


def read_png(p):
    data = p.read_bytes()
    assert data[:8] == b'\x89PNG\r\n\x1a\n'
    pos, idat, w = 8, b'', 0
    while pos < len(data):
        n, = struct.unpack('>I', data[pos:pos + 4])
        typ, body = data[pos + 4:pos + 8], data[pos + 8:pos + 8 + n]
        pos += 12 + n
        if typ == b'IHDR':
            w, h, depth, ctype, _, _, inter = struct.unpack('>IIBBBBB', body)
            assert depth == 8 and inter == 0 and ctype in (2, 6), (depth, ctype, inter)
            bpp = 4 if ctype == 6 else 3
        elif typ == b'IDAT':
            idat += body
    raw = zlib.decompress(idat)
    stride = w * bpp
    rows, prev, i = [], bytearray(stride), 0
    for _ in range(h):
        f = raw[i]
        line = bytearray(raw[i + 1:i + 1 + stride])
        i += 1 + stride
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
    px = [[tuple(r[x * bpp:x * bpp + bpp]) + ((255,) if bpp == 3 else ()) for x in range(w)] for r in rows]
    return w, h, px


def write_png(p, w, h, px):
    raw = b''.join(b'\x00' + bytes(v for pt in row for v in pt) for row in px)

    def chunk(t, b):
        return struct.pack('>I', len(b)) + t + b + struct.pack('>I', zlib.crc32(t + b) & 0xFFFFFFFF)

    p.write_bytes(b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b''))


def darken(pt):
    r, g, b, a = pt
    # 与浅底的接近度：越接近底色越替换为深底（边缘平滑过渡）
    d = max(abs(r - LIGHT[0]), abs(g - LIGHT[1]), abs(b - LIGHT[2]))
    k = max(0.0, min(1.0, 1 - d / 60))
    mix = lambda c, i: round(c * (1 - k) + DARK[i] * k)
    return (mix(r, 0), mix(g, 1), mix(b, 2), a)


for name in ('LaunchImage.png', 'LaunchImage@2x.png', 'LaunchImage@3x.png'):
    w, h, px = read_png(DIR / name)
    out = DIR / name.replace('LaunchImage', 'LaunchImageDark')
    write_png(out, w, h, [[darken(pt) for pt in row] for row in px])
    print(out.name, w, h)
