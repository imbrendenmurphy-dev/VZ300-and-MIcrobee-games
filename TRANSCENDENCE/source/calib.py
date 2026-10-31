# derive per-site multipliers from sites.txt + demo.lst
import re, json, sys
TI = float(sys.argv[1]) if len(sys.argv) > 1 else 360
addr2site = {}
for ln in open('demo.lst'):
    m = re.match(r'^\s*\d+\+?\s+([0-9A-F]{4})\s+\.TK(\d+):', ln)
    if m: addr2site[int(m.group(1), 16)] = m.group(2)
kt = {}
try: kt = json.load(open('ticks.json'))
except Exception: pass
worst = []
for ln in open('sites.txt'):
    a, mean, cnt = ln.split(); a = int(a, 16); mean = float(mean)
    if a in addr2site:
        k = max(1, min(8, round(mean / TI)))
        kt[addr2site[a]] = k
        worst.append((mean, addr2site[a], int(cnt), k))
json.dump(kt, open('ticks.json', 'w'))
worst.sort(reverse=True)
for w in worst[:15]: print('site %s mean %.0f n=%d K=%d' % (w[1], w[0], w[2], w[3]))
