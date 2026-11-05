# executed inside gen.py: sprite art for TENNIS II
# Sprite pixels: '.' transparent, 'L' light (skin/racket/ball), 'D' dark (hair/shoes/shadow),
# 'T' team colour. Team A copies use logical colour 2, team B logical 3, L = 1, D = 0.
# Every sprite is 8 px wide (stored as 2 bytes + 2 mask bytes per row, shifted at run time).

# --- far-end player (seen from the front, at the top of the screen)
F_IDLE = """
..DDD...
..LLL...
..LDL...
.TTTTT..
L.TTT.L.
..TTT..L
..TTT.LL
..L.L...
..L.L...
.DD.DD..
"""
F_RUN1 = """
..DDD...
..LLL...
..LDL...
.TTTTT..
L.TTT.L.
..TTT..L
..TTT.LL
.L...L..
L.....L.
D.....D.
"""
F_RUN2 = """
..DDD...
..LLL...
..LDL...
.TTTTT..
L.TTT.L.
..TTT..L
..TTT.LL
...LL...
...LL...
...DD...
"""
F_FORE = """
..DDD...
..LLL...
..LDL...
.TTTTTLL
L.TTT.LL
..TTT...
..TTT...
..L.L...
.L...L..
DD...DD.
"""
F_BACK = """
..DDD...
..LLL...
..LDL...
LLTTTTT.
LL.TTT.L
...TTT..
...TTT..
...L.L..
..L...L.
.DD...DD
"""
F_SERVE1 = """
..DDD.LL
..LLL.LL
..LDL.L.
.TTTTTL.
L.TTT...
..TTT...
..TTT...
..L.L...
..L.L...
.DD.DD..
"""
F_SERVE2 = """
LL.DDD..
LL.LLL..
.L.LDL..
..LTTTT.
...TTT.L
...TTT..
...TTT..
..L..L..
.L....L.
DD....DD
"""
F_JOY = """
L.DDD.L.
L.LLL.L.
L.LDL.L.
.TTTTT..
..TTT...
..TTT...
..TTT...
..L.L...
..L.L...
.DD.DD..
"""
F_SAD = """
........
..DDD...
..LLL...
.TTTTT..
L.TTT.L.
..TTT...
..TTT..L
..L.L.LL
..L.L...
.DD.DD..
"""

# --- near-end player (seen from behind, at the bottom of the screen)
N_IDLE = """
..DDD...
..DDD...
..LLL...
.TTTTT..
L.TTT.L.
..TTT..L
..TTT.LL
..L.L...
..L.L...
.DD.DD..
"""
N_RUN1 = """
..DDD...
..DDD...
..LLL...
.TTTTT..
L.TTT.L.
..TTT..L
..TTT.LL
.L...L..
L.....L.
D.....D.
"""
N_RUN2 = """
..DDD...
..DDD...
..LLL...
.TTTTT..
L.TTT.L.
..TTT..L
..TTT.LL
...LL...
...LL...
...DD...
"""
N_FORE = """
..DDD.LL
..DDD.LL
..LLL.L.
.TTTTTL.
L.TTT...
..TTT...
..TTT...
..L.L...
.L...L..
DD...DD.
"""
N_BACK = """
LL.DDD..
LL.DDD..
.L.LLL..
.LTTTTT.
...TTT.L
...TTT..
...TTT..
...L.L..
..L...L.
.DD...DD
"""
N_SERVE1 = """
......LL
..DDD.LL
..DDD.L.
..LLL.L.
.TTTTTL.
L.TTT...
..TTT...
..L.L...
..L.L...
.DD.DD..
"""
N_SERVE2 = """
..DDD...
..DDD...
..LLL...
.TTTTTL.
L.TTT.LL
..TTT.LL
..TTT...
..L..L..
.L....L.
DD....DD
"""
N_JOY = """
L.DDD.L.
L.DDD.L.
L.LLL.L.
.TTTTT..
..TTT...
..TTT...
..TTT...
..L.L...
..L.L...
.DD.DD..
"""
N_SAD = """
........
..DDD...
..DDD...
.TTTTT..
L.TTT.L.
..TTT...
..TTT..L
..L.L.LL
..L.L...
.DD.DD..
"""

PLAYER_FRAMES = ["IDLE", "RUN1", "RUN2", "FORE", "BACK", "SERVE1", "SERVE2", "JOY", "SAD"]
FAR = [F_IDLE, F_RUN1, F_RUN2, F_FORE, F_BACK, F_SERVE1, F_SERVE2, F_JOY, F_SAD]
NEAR = [N_IDLE, N_RUN1, N_RUN2, N_FORE, N_BACK, N_SERVE1, N_SERVE2, N_JOY, N_SAD]

BALL = """
LL
LL
"""
BALLS = """
L.
"""
SHADOW = """
DD
"""
PUFF1 = """
.L.L.
L...L
"""
PUFF2 = """
L...L
.....
L...L
"""
CONE = """
..T..
.TTT.
TLTLT
"""
CONE_HIT = """
L.L.L
.LLL.
LLLLL
"""
MACHINE = """
.DDDD.
DTTTTD
DTLLTD
DTTTTD
.D..D.
"""
FLAG = """
LT
LT
L.
L.
"""
FIRE1 = """
.L..
L.L.
.L.L
"""
FIRE2 = """
..L.
.L.L
L.L.
"""
