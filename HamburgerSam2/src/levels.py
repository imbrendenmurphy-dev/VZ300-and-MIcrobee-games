# HAMBURGER SAM II - kitchen layouts (executed in gen.py's namespace)
# 32 cells of 4 px across. Floors 0 (top) .. 4 (bottom).
#   girders: 5 strings, '=' girder, '.' gap (gaps given as (from, to) cell ranges)
#   ladders: 4 lists (between floor f and f+1), each the ladder's left cell c
#            (a ladder is 8 px wide: cells c and c+1, climbers stand at x = 4c)
#   cols:    left cell of each burger column (pieces are 4 cells = 16 px wide)
#   pieces:  per column, 5 chars top->bottom floor: T top bun, L lettuce, C cheese,
#            M meat, O tomato, B bottom bun, '.' nothing on that floor
#   roster:  enemy types in spawn order: H hot dog, E egg, P pickle, C chilli
# Physical colours: css 0 = green/yellow/blue/red, css 1 = buff/cyan/magenta/orange.


def full():
    return "=" * 32


def gaps(*rng):
    s = list("=" * 32)
    for a, b in rng:
        for i in range(a, b + 1):
            s[i] = '.'
    return "".join(s)


KITCHENS = [
    dict(name="SAM'S DINER", css=0, gcol=1, lcol=1,
         girders=[full(), full(), full(), full(), full()],
         ladders=[[7, 15, 23], [0, 15, 29], [7, 14, 23], [0, 16, 29]],
         cols=[2, 9, 19, 25], pieces=["T.LMB", "TLM.B", "TLM.B", "T.LMB"],
         sam=(60, 4), item=(60, 2), spawns=[(0, 0), (116, 0), (0, 4), (116, 4)],
         roster="HHEHHE", maxen=3, speed=0),
    dict(name="CHEESE FACTORY", css=0, gcol=2, lcol=1,
         girders=[full(), gaps((14, 17)), full(), gaps((0, 0), (31, 31)), full()],
         ladders=[[0, 7, 23, 29], [6, 23], [0, 14, 29], [7, 16, 23]],
         cols=[2, 9, 18, 25], pieces=["TLCMB", "T.CMB", "TC.MB", "TLCMB"],
         sam=(56, 4), item=(56, 2), spawns=[(0, 0), (116, 0), (0, 4), (116, 4)],
         roster="HEHPEH", maxen=4, speed=0),
    dict(name="PICKLE PANTRY", css=0, gcol=1, lcol=2,
         girders=[gaps((0, 1), (30, 31)), full(), gaps((14, 16)), full(), full()],
         ladders=[[6, 22], [0, 12, 16, 29], [6, 22], [0, 12, 22, 29]],
         cols=[2, 8, 18, 24], pieces=["TLM.B", "T.LMB", "TLM.B", "T.LMB"],
         sam=(60, 4), item=(60, 3), spawns=[(116, 1), (0, 1), (0, 4), (116, 4)],
         roster="PHPEHC", maxen=4, speed=8),
    dict(name="NIGHT GRILL", css=1, gcol=1, lcol=2,
         girders=[full(), full(), gaps((21, 23)), full(), full()],
         ladders=[[6, 15, 23], [0, 14, 29], [6, 14, 23], [0, 14, 29]],
         cols=[2, 9, 17, 25], pieces=["TLCMB", "TLMOB", "TOLMB", "TCLMB"],
         sam=(56, 4), item=(56, 1), spawns=[(0, 0), (116, 0), (0, 4), (116, 4)],
         roster="EHCHEP", maxen=4, speed=8),
    dict(name="SALAD BAR", css=0, gcol=3, lcol=1,
         girders=[gaps((0, 0), (31, 31)), full(), full(), gaps((14, 15)), full()],
         ladders=[[7, 14, 22], [0, 7, 22, 29], [6, 21], [0, 6, 22, 29]],
         cols=[2, 9, 17, 24], pieces=["TOLOB", "TLOMB", "TLOMB", "TOLOB"],
         sam=(60, 4), item=(60, 2), spawns=[(116, 1), (0, 1), (0, 4), (116, 4)],
         roster="PEPHCE", maxen=5, speed=12),
    dict(name="FRY-UP FACTORY", css=0, gcol=2, lcol=3,
         girders=[gaps((14, 17)), gaps((0, 0), (31, 31)), full(), gaps((15, 16)), full()],
         ladders=[[6, 22], [6, 13, 16, 23], [0, 13, 29], [0, 6, 22, 29]],
         cols=[2, 9, 18, 25], pieces=["TCLMB", "TLCMB", "TMCLB", "TCMLB"],
         sam=(56, 4), item=(56, 2), spawns=[(0, 0), (116, 0), (0, 4), (116, 4)],
         roster="CHEHPC", maxen=5, speed=16),
    dict(name="MIDNIGHT FEAST", css=1, gcol=2, lcol=1,
         girders=[full(), gaps((14, 17)), gaps((0, 0), (31, 31)), gaps((15, 16)), full()],
         ladders=[[0, 6, 22, 29], [6, 23], [6, 13, 16, 23], [0, 7, 22, 29]],
         cols=[2, 9, 18, 25], pieces=["TLOMB", "TCLMB", "TLCMB", "TOLMB"],
         sam=(60, 4), item=(60, 0), spawns=[(0, 0), (116, 0), (0, 4), (116, 4)],
         roster="CPECHP", maxen=5, speed=20),
    dict(name="BURGER PALACE", css=0, gcol=3, lcol=2,
         girders=[gaps((14, 17)), full(), gaps((13, 15)), full(), full()],
         ladders=[[6, 22], [0, 7, 16, 29], [6, 16, 23], [0, 13, 22, 29]],
         cols=[2, 9, 18, 25], pieces=["TLCMB", "TOCMB", "TCOMB", "TLCMB"],
         sam=(60, 4), item=(60, 1), spawns=[(0, 1), (116, 1), (0, 4), (116, 4)],
         roster="HCEPCH", maxen=6, speed=24),
]
# the Easter egg: a recreation of the 1984 original's kitchen (3 columns, one ingredient per floor)
CLASSIC = dict(name="CLASSIC 1984", css=0, gcol=1, lcol=1,
               girders=[gaps((0, 0), (31, 31))] * 5,
               ladders=[[1, 8, 17, 23, 29], [1, 9, 15, 23, 29], [1, 8, 17, 23, 29], [1, 9, 15, 23, 29]],
               cols=[3, 11, 25], pieces=["TLCMB", "TLCMB", "TLCMB"],
               sam=(4, 4), item=(76, 2), spawns=[(116, 0), (4, 0), (116, 2), (116, 4)],
               roster="HHHEPE", maxen=4, speed=0)
