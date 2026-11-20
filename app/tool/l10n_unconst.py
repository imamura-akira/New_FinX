#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""F18 辅助（开发用）：文案替换为 t.xxx 后，去掉因此失效的 const 关键字。

    python3 tool/l10n_unconst.py      # 反复执行 flutter analyze，按报错位置删除最近的包裹 const，直到没有此类错误

声明式常量（const x = t.y）无法自动处理，会列出来手工改为 getter。
"""
import re
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CODES = {
    'const_with_non_constant_argument', 'non_constant_list_element', 'non_constant_map_element',
    'non_constant_map_value', 'non_constant_set_element', 'invalid_constant', 'const_eval_method_invocation',
    'const_eval_property_access', 'const_initialized_with_non_constant_value', 'non_constant_map_key',
    'const_constructor_param_type_mismatch', 'const_eval_type_bool_num_string',
}
LINE = re.compile(r'^\s*error • .* • (.+?):(\d+):(\d+) • (\w+)$')


def analyze():
    out = subprocess.run(['flutter', 'analyze', '--no-pub'], cwd=ROOT, capture_output=True, text=True).stdout
    errs = []
    for ln in out.splitlines():
        m = LINE.match(ln)
        if m and m.group(4) in CODES:
            errs.append((m.group(1), int(m.group(2)), int(m.group(3)), m.group(4)))
    return errs


def offset(src, line, col):
    lines = src.split('\n')
    return sum(len(l) + 1 for l in lines[:line - 1]) + col - 1


DECL = re.compile(r'\bconst\s+(?:[A-Za-z_<>?,\s]+\s+)?[A-Za-z_]\w*\s*=')


def main():
    manual = set()
    for rnd in range(30):
        errs = analyze()
        if not errs:
            break
        fixes = {}
        for f, line, col, code in errs:
            p = ROOT / f
            src = p.read_text(encoding='utf-8')
            pos = offset(src, line, col)
            for m in reversed(list(re.finditer(r'\bconst\b', src[:pos]))):
                if DECL.match(src, m.start()):
                    manual.add('%s:%d' % (f, src.count('\n', 0, m.start()) + 1))
                    break
                fixes.setdefault(p, set()).add(m.start())
                break
        if not fixes:
            break
        for p, starts in fixes.items():
            src = p.read_text(encoding='utf-8')
            for s in sorted(starts, reverse=True):
                end = s + 5
                while end < len(src) and src[end] == ' ':
                    end += 1
                src = src[:s] + src[end:]
            p.write_text(src, encoding='utf-8')
        print('round %d: removed %d const' % (rnd + 1, sum(len(v) for v in fixes.values())))
    left = analyze()
    for e in left:
        print('剩余:', e)
    for m in sorted(manual):
        print('需手工改为 getter:', m)
    sys.exit(1 if left else 0)


if __name__ == '__main__':
    main()
