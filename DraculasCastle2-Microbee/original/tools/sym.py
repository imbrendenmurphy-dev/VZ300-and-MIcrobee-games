import sys, bisect
S = sorted((int(l.split()[0], 16), l.split()[1]) for l in open(__import__('os').environ.get('SYM','/home/claude/dc2/build/DRACDBG.sym')))
A = [a for a, n in S]
def name(pc):
    i = bisect.bisect_right(A, pc) - 1
    return '%s+%d' % (S[i][1], pc - S[i][0]) if i >= 0 else '?'
for tok in sys.stdin.read().split():
    try: pc = int(tok, 16)
    except: continue
    print('%04X %s' % (pc, name(pc)))
