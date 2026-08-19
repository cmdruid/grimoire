#!/usr/bin/env python3
"""Per-skill debt census over a skills library. Generated, not hand-counted.

Usage: debt-census.py <skills-dir>
Emits fact tables only -- it never recommends an action.
"""
import os, re, sys, hashlib, collections

ROOT = sys.argv[1] if len(sys.argv) > 1 else '.'

LEGACY = re.compile(r'\b(legacy|deprecated|retired|superseded|no longer|used to\b|previously|'
                    r'historical|backward[- ]compat|for compat|grandfather|migrat\w+ path|'
                    r'old (?:home|name|path|form)|still (?:names|calls|reads))\b', re.I)
RATIONALE = re.compile(r'\b(because|the reason|why (?:this|it|3b|we)|lesson|we learned|has bitten|'
                       r'post-?mortem|rationale|the trap|failure mode|exists to prevent|'
                       r'this is why|earned|doctrine:|died|wrong (?:a |the )?\w*(?:th|st|nd|rd) time)\b', re.I)
HEDGE = re.compile(r'\b(except\b|unless\b|caveat|note that|carve-?out|edge case|however|'
                   r'but only|caution|beware|do not confuse|asymmetr|deliberately|'
                   r'one exception|the exception)\b', re.I)


def md_files(d):
    for root, _, files in os.walk(d):
        for f in sorted(files):
            if f.endswith('.md'):
                yield os.path.join(root, f)


def sh_files(d):
    for root, _, files in os.walk(d):
        for f in sorted(files):
            if f.endswith('.sh'):
                yield os.path.join(root, f)


def paragraphs(text):
    """Yield (lines, text) per blank-line-delimited block, code fences excluded."""
    out, buf, fence = [], [], False
    for line in text.split('\n'):
        if line.strip().startswith('```'):
            fence = not fence
            continue
        if fence:
            continue
        if line.strip() == '':
            if buf:
                out.append(buf)
                buf = []
        else:
            buf.append(line)
    if buf:
        out.append(buf)
    return out


skills = sorted(d for d in os.listdir(ROOT) if os.path.isdir(os.path.join(ROOT, d)))
rows = []
dup_md, dup_sh = collections.defaultdict(list), collections.defaultdict(list)

for s in skills:
    d = os.path.join(ROOT, s)
    md_total = leg = rat = hed = fence_lines = 0
    for p in md_files(d):
        t = open(p, encoding='utf8', errors='ignore').read()
        md_total += t.count('\n') + 1
        dup_md[hashlib.md5(t.encode()).hexdigest()].append(os.path.relpath(p, ROOT))
        infence = False
        for line in t.split('\n'):
            if line.strip().startswith('```'):
                infence = not infence
                fence_lines += 1
            elif infence:
                fence_lines += 1
        for para in paragraphs(t):
            body = ' '.join(para)
            n = len(para)
            if LEGACY.search(body):
                leg += n
            elif RATIONALE.search(body):
                rat += n
            elif HEDGE.search(body):
                hed += n

    sh_run = sh_test = 0
    for p in sh_files(d):
        n = open(p, encoding='utf8', errors='ignore').read().count('\n') + 1
        dup_sh[hashlib.md5(open(p, 'rb').read()).hexdigest()].append(os.path.relpath(p, ROOT))
        if '/tests/' in p:
            sh_test += n
        else:
            sh_run += n
    rows.append((s, md_total, leg, rat, hed, fence_lines, sh_run, sh_test))

W = '{:<15}{:>7}{:>7}{:>7}{:>7}{:>8}{:>8}{:>7}{:>7}'
print('=== PER-SKILL DEBT CENSUS (lines) ===')
print(W.format('skill', 'md', 'legacy', 'ratio', 'hedge', 'flagged', 'flag%', 'sh-run', 'sh-tst'))
print('-' * 74)
tot = [0] * 7
for s, md, leg, rat, hed, fen, shr, sht in sorted(rows, key=lambda r: -(r[2] + r[3] + r[4])):
    flag = leg + rat + hed
    pct = round(100 * flag / md) if md else 0
    print(W.format(s, md, leg, rat, hed, flag, f'{pct}%', shr, sht))
    for i, v in enumerate([md, leg, rat, hed, flag, shr, sht]):
        tot[i] += v
print('-' * 74)
print(W.format('TOTAL', tot[0], tot[1], tot[2], tot[3], tot[4],
               f'{round(100 * tot[4] / tot[0])}%', tot[5], tot[6]))

print('\n=== EXACT-DUPLICATE FILES (copy-paste across skills) ===')
dupes = 0
for kind, table in (('sh', dup_sh), ('md', dup_md)):
    for h, paths in sorted(table.items(), key=lambda kv: -len(kv[1])):
        if len(paths) > 1:
            n = open(os.path.join(ROOT, paths[0]), encoding='utf8', errors='ignore').read().count('\n') + 1
            waste = n * (len(paths) - 1)
            dupes += waste
            print(f'  [{kind}] {len(paths)}x {n:>4} lines ({waste:>4} redundant): ' + ', '.join(paths))
print(f'  --> redundant lines from exact duplication: {dupes}')
