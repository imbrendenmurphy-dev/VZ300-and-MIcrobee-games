# tone-based rendering: materials return (ramp, index); depth fog shifts index
B2 = [[0.125, 0.625], [0.875, 0.375]]
def pick(entry, x, y):
    c1, c2, f = entry
    return c2 if f > B2[y & 1][x & 1] else c1
G, Y, B, R = 0, 1, 2, 3   # CSS0
BU, CY, MA, OR = 0, 1, 2, 3  # CSS1
def ramp(*e): return list(e)
def fogstep(z):
    if z < 1.6: return 0
    if z < 2.6: return 1
    if z < 3.5: return 2
    return 3
