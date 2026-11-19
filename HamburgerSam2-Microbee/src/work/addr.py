import sys, re, bisect
from pathlib import Path
sym = {k: int(v, 16) for k, v in re.findall(r'^(\S+): EQU 0x([0-9A-Fa-f]+)', Path('work/port/build/game.sym').read_text(), re.M)}
labels = sorted((v, k) for k, v in sym.items())
addrs = [a for a, _ in labels]
for a in sys.argv[1:]:
    pc = int(a, 16); i = bisect.bisect_right(addrs, pc) - 1
    print(a, labels[i][1], '+', pc - labels[i][0])
