from pathlib import Path
ROOT = Path(__file__).resolve().parent.parent
def load():
    sym = {}
    for l in open(ROOT / 'build' / 'main.sym'):
        p = l.split()
        if len(p) >= 3 and p[1] == 'EQU':
            sym[p[0].rstrip(':')] = int(p[2][2:], 16)
    return sym
