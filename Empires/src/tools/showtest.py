import sys, os, json
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import showcase as S
p = json.load(open('show/plan.json'))
B = S.build_cmds(p['sx'], p['sy'], [tuple([a, tuple(b)]) for a, b in p['P1']], [tuple([a, tuple(b)]) for a, b in p['P2']])
L = S.PRE + B + ['frames 20', 'shot show/t_built.bin', 'poke %04X 03' % S.sym['speed']]
for i in range(6):
    L += ['frames 800', S.poke16('food', 4000), S.poke16('wood', 9000)]
L += ['shot show/t_grown.bin', 'mem show/t_m.bin']
print(len(L)); r = S.run(L); print(r[-300:])
m = open('show/t_m.bin', 'rb').read()
w = lambda n: m[S.sym[n]] | m[S.sym[n] + 1] << 8
print('nbld', m[S.sym['nbld']], 'pop', w('pop'), 'year', w('year'), 'happy', m[S.sym['happy']])
