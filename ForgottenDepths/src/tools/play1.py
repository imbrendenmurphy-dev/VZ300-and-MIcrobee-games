"""scripted playthrough helper: steps -> key script"""
import sys
sys.path.insert(0, '/home/claude/depths/tools')
import run

def path(moves, start=110, hold=5, gap=8):
    """moves: list of (key, count) ; returns script, end frame"""
    sc = []
    f = start
    for k, n in moves:
        for i in range(n):
            sc.append((f, k, hold))
            f += gap
    return sc, f

DESCENT = [('D', 1)] + [('R', 1), ('D', 1)] * 8 + [('R', 22)]
