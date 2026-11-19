"""mkscr.py NAME : write emu/NAME.scr from a template with $symbol substitution"""
import sys, re
S = {}
for l in open('build/galahxy.sym'):
    a, n = l.split(); S[n] = int(a, 16)
def sub(t): return re.sub(r'\$(\w+)(\+\d+)?', lambda m: '%04X' % (S[m.group(1)] + int(m.group(2) or 0)) if m.group(1) in S else m.group(0), t)
HEAD = """mapper 1
crash 1
okpc 8000 $code_end
okpc B800 E3FF
okpc E400 $com_hi_end
okpc 0038 003A
okpc 7D7D 7D7F
okpc 5F00 5F0A
sd build/sd
"""
body = open('emu/%s.tpl' % sys.argv[1]).read()
open('emu/%s.scr' % sys.argv[1], 'w').write(sub(HEAD + body))
