#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""F18 文案抽取工具（开发用）：把 Dart 源文件中含中文的字符串字面量替换为 `t.key(...)`，并写入 ARB。

    python3 tool/l10n_extract.py scan lib/features/x/y.dart          # 列出待抽取的字面量（带序号）
    python3 tool/l10n_extract.py apply lib/features/x/y.dart prefix tr.json

tr.json：与 scan 序号对齐的数组；每项为 null（跳过）、英文字符串，或 {"en": ..., "key": ...}。
英文中的占位符用 scan 输出里中文版本的 {name}。注释、Key(...) 内的字面量、插值里含引号的字面量不处理（scan 中标出）。
"""
import json
import re
import sys
from collections import OrderedDict
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
ARB = {'zh': ROOT / 'lib/l10n/app_zh.arb', 'en': ROOT / 'lib/l10n/app_en.arb'}
HAN = re.compile(r'[一-鿿　-〿＀-￯]')


def literals(src):
    """返回 [(start, end, quote, raw_body)]，跳过注释；raw 字符串与三引号不处理。"""
    out, i, n = [], 0, len(src)
    while i < n:
        c = src[i]
        if src.startswith('//', i):
            i = src.find('\n', i)
            if i < 0:
                break
            continue
        if src.startswith('/*', i):
            i = src.find('*/', i) + 2
            continue
        if c in '\'"':
            raw = i > 0 and src[i - 1] == 'r'
            if src.startswith(c * 3, i):
                j = src.find(c * 3, i + 3)
                i = j + 3
                continue
            j, depth = i + 1, 0
            while j < n:
                ch = src[j]
                if ch == '\\' and not raw:
                    j += 2
                    continue
                if not raw and src.startswith('${', j):
                    depth, j = 1, j + 2
                    while j < n and depth:
                        if src[j] == '{':
                            depth += 1
                        elif src[j] == '}':
                            depth -= 1
                        elif src[j] in '\'"':  # 插值内的嵌套字符串
                            q = src[j]
                            j += 1
                            while j < n and src[j] != q:
                                j += 2 if src[j] == '\\' else 1
                        j += 1
                    continue
                if ch == c:
                    break
                j += 1
            if not raw:
                out.append((i, j + 1, c, src[i + 1:j]))
            i = j + 1
            continue
        i += 1
    return out


IDENT = re.compile(r'\$([A-Za-z_][A-Za-z0-9_]*)')


def parse(body):
    """把字面量正文转为 (zh 文本含 {name}, [dart 表达式], [name], 问题)。"""
    text, exprs, names, problem, i = '', [], [], None, 0
    while i < len(body):
        ch = body[i]
        if ch == '\\':
            nx = body[i + 1]
            text += {'n': '\n', 't': '\t', '$': '$', "'": "'", '"': '"', '\\': '\\'}.get(nx, nx)
            i += 2
            continue
        if body.startswith('${', i):
            depth, j = 1, i + 2
            while depth:
                if body[j] == '{':
                    depth += 1
                elif body[j] == '}':
                    depth -= 1
                j += 1
            expr = body[i + 2:j - 1].strip()
            if '\'' in expr or '"' in expr:
                problem = 'nested-quote'
            m = re.fullmatch(r'(?:[A-Za-z_]\w*[!?]?\.)*([A-Za-z_]\w*)[!?]?(?:\(\))?', expr)
            name = m.group(1) if m else 'v%d' % len(exprs)
            exprs.append(expr)
            names.append(name)
            text += '{' + name + '}'
            i = j
            continue
        if ch == '$':
            m = IDENT.match(body, i)
            if m:
                exprs.append(m.group(1))
                names.append(m.group(1))
                text += '{' + m.group(1) + '}'
                i = m.end()
                continue
        text += ch
        i += 1
    if len(set(names)) != len(names):  # 同名占位符（同一表达式出现两次等）需手工处理
        problem = problem or 'dup-name'
    return text, exprs, names, problem


def candidates(path):
    src = path.read_text(encoding='utf-8')
    res = []
    for (s, e, q, body) in literals(src):
        if not HAN.search(body):
            continue
        before = src[max(0, s - 12):s]
        line = src.count('\n', 0, s) + 1
        flag = None
        if re.search(r'Key\($', before):
            flag = 'key'
        text, exprs, names, problem = parse(body)
        res.append(dict(start=s, end=e, line=line, body=body, zh=text, exprs=exprs, names=names, flag=flag or problem))
    return src, res


def slug(en, prefix):
    words = re.findall(r'[A-Za-z0-9]+', re.sub(r'\{[^}]*\}', ' ', en))[:4] or ['text']
    s = prefix + ''.join(w[:1].upper() + w[1:].lower() for w in words)
    return re.sub(r'^[^a-z]', lambda m: m.group(0).lower(), s)


def load(lang):
    p = ARB[lang]
    if not p.exists():
        return OrderedDict([('@@locale', lang)])
    return json.loads(p.read_text(encoding='utf-8'), object_pairs_hook=OrderedDict)


def save(lang, d):
    ARB[lang].parent.mkdir(parents=True, exist_ok=True)
    ARB[lang].write_text(json.dumps(d, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')


def cmd_scan(path):
    _, cs = candidates(path)
    for k, c in enumerate(cs):
        print('%3d L%-4d %-12s %s' % (k, c['line'], c['flag'] or '', json.dumps(c['zh'], ensure_ascii=False)))


def cmd_apply(path, prefix, trpath):
    src, cs = candidates(path)
    trs = json.loads(Path(trpath).read_text(encoding='utf-8'))
    if len(trs) != len(cs):
        sys.exit('翻译条数 %d 与候选 %d 不一致' % (len(trs), len(cs)))
    zh, en = load('zh'), load('en')
    by_text = {(v, en.get(k)): k for k, v in zh.items() if not k.startswith('@') and isinstance(v, str)}
    edits = []
    for c, tr in zip(cs, trs):
        if tr is None:
            continue
        if c['flag'] in ('key', 'nested-quote', 'dup-name'):
            sys.exit('L%d 需手工处理（%s），翻译项应为 null' % (c['line'], c['flag']))
        if isinstance(tr, str):
            tr = {'en': tr}
        for nm in c['names']:
            if '{' + nm + '}' not in tr['en']:
                sys.exit('L%d 英文缺少占位符 {%s}: %s' % (c['line'], nm, tr['en']))
        key = by_text.get((c['zh'], tr['en']))
        if key is None:
            key = tr.get('key') or slug(tr['en'], prefix)
            base, k = key, 2
            while key in zh:
                key, k = '%s%d' % (base, k), k + 1
            zh[key] = c['zh']
            en[key] = tr['en']
            if c['names']:
                zh['@' + key] = {'placeholders': {nm: {'type': 'Object'} for nm in c['names']}}
            by_text[(c['zh'], tr['en'])] = key
        repl = 't.%s' % key if not c['exprs'] else 't.%s(%s)' % (key, ', '.join(c['exprs']))
        edits.append((c['start'], c['end'], repl))
    for s, e, r in sorted(edits, reverse=True):
        src = src[:s] + r + src[e:]
    if edits and 'l10n/l10n.dart' not in src:
        rel = Path(*(['..'] * (len(path.resolve().relative_to(ROOT / 'lib').parts) - 1)), 'l10n', 'l10n.dart').as_posix()
        imports = list(re.finditer(r"^import '[^']+';\n", src, re.M))
        at = imports[-1].end() if imports else 0
        src = src[:at] + "import '%s';\n" % rel + src[at:]
    path.write_text(src, encoding='utf-8')
    save('zh', zh)
    save('en', en)
    print('replaced %d literals' % len(edits))


if __name__ == '__main__':
    if sys.argv[1] == 'scan':
        cmd_scan(Path(sys.argv[2]))
    else:
        cmd_apply(Path(sys.argv[2]), sys.argv[3], sys.argv[4])
