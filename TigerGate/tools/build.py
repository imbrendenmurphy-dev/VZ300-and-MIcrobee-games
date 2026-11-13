#!/usr/bin/env python3
# Build TIGER GATE: art + packs, preprocess (" : " and rept), assemble, wrap as .VZ
import os, re, subprocess, sys
os.chdir(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..'))
subprocess.check_call([sys.executable, 'tools/gen.py', 'gen', 'build/sd'])
auto = int(sys.argv[1]) if len(sys.argv) > 1 else 0
dstg = int(sys.argv[2]) if len(sys.argv) > 2 else 1
open('gen/opts.asm', 'w').write('AUTOPLAY equ %d\nDBGSTAGE equ %d\n' % (auto, dstg))
outname = 'TIGRGATE' if not auto else 'AUTO%d' % dstg

def split_q(s, sep):
    out = []; cur = ''; q = False; i = 0
    while i < len(s):
        if s[i] == '"': q = not q
        if not q and s.startswith(sep, i):
            out.append(cur); cur = ''; i += len(sep); continue
        cur += s[i]; i += 1
    return out+[cur]
def nocomment(s):
    q = False
    for i, ch in enumerate(s):
        if ch == '"': q = not q
        elif ch == ';' and not q: return s[:i]
    return s
lines = [nocomment(l).rstrip() for l in open('src/game.asm').read().split('\n')]
out = []; i = 0
while i < len(lines):
    m = re.match(r'^\s*rept\s+(\d+)\s*$', lines[i])
    if m:
        j = i+1
        while lines[j].strip() != 'endr': j += 1
        out += lines[i+1:j]*int(m.group(1)); i = j+1
    else:
        out.append(lines[i]); i += 1
final = []
for l in out:
    for st in split_q(l, ' : '):
        st = st.strip()
        if not st: continue
        m = re.match(r'^(\.?[A-Za-z_]\w*):\s*(.*)$', st)
        if m:
            final.append(m.group(1)+':')
            if m.group(2): final.append('    '+m.group(2))
        elif re.match(r'^[A-Za-z_]\w*\s+equ\s', st): final.append(st)
        else: final.append('    '+st)
open('game.pp.asm', 'w').write('\n'.join(final)+'\n')
subprocess.check_call([sys.executable, 'tools/z80asm.py', 'game.pp.asm', 'build/'+outname+'.bin', 'build/'+outname+'.sym'])
subprocess.check_call([sys.executable, 'tools/mkvz.py', 'build/'+outname+'.bin', ('build/sd/' if not auto else 'build/')+outname+'.VZ', '8000', 'TIGER GATE'])
