# HAMBURGER SAM II - sprite and ingredient art (all original, BPM 2026)
# Executed in gen.py's namespace.
# Sprites are 8 px wide x 8 rows.  '.' transparent, 'g' green/background (opaque),
# 'Y' colour 1 (yellow / cyan), 'B' colour 2 (blue / magenta), 'R' colour 3 (red / orange).
# Right-facing frames; left-facing ones are mirrored by gen.py.

SAM_A = """
..YYYY..
.YYYYYY.
..BBBB..
..YYBYY.
..RRRR..
.YRRRRY.
..BBBB..
..B..B..
"""
SAM_B = """
..YYYY..
.YYYYYY.
..BBBB..
..YYBYY.
..RRRR..
.YRRRRY.
..BBBB..
.BB...B.
"""
SAM_THROW = """
..YYYY..
.YYYYYY.
..BBBB..
..YYBYY.
..RRRRYY
.YRRRR..
..BBBB..
..B..B..
"""
SAM_CLIMB_A = """
..YYYY..
.YYYYYY.
.YBBBB..
.RYYYYR.
..RRRRY.
..RRRR..
..BBBB..
..B..B..
"""
SAM_CLIMB_B = """
..YYYY..
.YYYYYY.
..BBBBY.
.RYYYYR.
.YRRRR..
..RRRR..
..BBBB..
..B..B..
"""
SAM_FRONT = """
..YYYY..
.YYYYYY.
..BBBB..
..BYYB..
Y.RRRR.Y
.RRRRRR.
..BBBB..
..B..B..
"""
SAM_CHEER = """
Y.YYYY.Y
RYYYYYYR
.RBBBBR.
..BYYB..
..RYYR..
..RRRR..
..BBBB..
.B....B.
"""
SAM_DIZZY = """
.Y.Y.Y..
..YYYY..
.YYYYYY.
..BBBB..
..RYYR..
.YRRRRY.
..BBBB..
.B....B.
"""
SAM_PLATE = """
BBBBBBBB
.YYYYYY.
Y.BBBB.Y
R.BYYB.R
.RRRRRR.
..RRRR..
..BBBB..
..B..B..
"""

# --- the chasers ---------------------------------------------------------
HOTDOG_A = """
...RR...
..RRRR..
..RBRB..
..RRRR..
..YRRR..
..RYRR..
..RRYR..
..B..B..
"""
HOTDOG_B = """
...RR...
..RRRR..
..RBRB..
..RRRR..
..YRRR..
..RYRR..
..RRYR..
.B....B.
"""
EGG_A = """
...YY...
..YYYY..
.YYBYB..
.YYRRYY.
.YRRRRY.
.YYRRYY.
..YYYY..
..B..B..
"""
EGG_B = """
...YY...
..YYYY..
.YYBYB..
.YYRRYY.
.YRRRRY.
.YYRRYY.
..YYYY..
.B....B.
"""
PICKLE_A = """
...BB...
..BBBB..
..BYBY..
.BBBBB..
..BBBBB.
.BBBBB..
..BBBB..
..R..R..
"""
PICKLE_B = """
...BB...
..BBBB..
..BYBY..
.BBBBB..
..BBBBB.
.BBBBB..
..BBBB..
.R....R.
"""
CHILLI_A = """
....BB..
...BB...
..RRRR..
.RYRYRR.
.RRRRRR.
..RRRR..
...RRR..
..B..BR.
"""
CHILLI_B = """
....BB..
...BB...
..RRRR..
.RYRYRR.
.RRRRRR.
..RRRR..
...RRR..
.B...B.R
"""
STUN = {   # stunned versions: dizzy eyes and pepper sparkles
    'HOTDOG': """
Y.Y..Y..
..RRRR.Y
..RYRY..
..RRRR..
..YRRR..
..RYRR..
..RRYR..
..B..B..
""",
    'EGG': """
Y..Y..Y.
..YYYY..
.YYRYR..
.YYRRYY.
.YRRRRY.
.YYRRYY.
..YYYY..
..B..B..
""",
    'PICKLE': """
Y.Y..Y..
..BBBB.Y
..BRBR..
.BBBBB..
..BBBBB.
.BBBBB..
..BBBB..
..R..R..
""",
    'CHILLI': """
Y.Y.BBY.
...BB...
..RRRR..
.RBRBRR.
.RRRRRR.
..RRRR..
...RRR..
..B..BR.
""",
}
SQUASH = {
    'HOTDOG': "\n\n\n\n\n.Y.RR.Y.\nRRRRRRRR\n.RYRYRR.\n",
    'EGG':    "\n\n\n\n\n.Y.YY.Y.\nYYYRRYYY\n.YYYYYY.\n",
    'PICKLE': "\n\n\n\n\n.Y.BB.Y.\nBBBBBBBB\n.BBYBBB.\n",
    'CHILLI': "\n\n\n\n\n.Y.BB.Y.\nRRRRRRRR\n.RRRRRR.\n",
}
PEPPER_A = """
........
..Y.B...
.B.Y.Y..
Y.B.Y.B.
.Y.B.Y..
..B.Y...
...Y....
........
"""
PEPPER_B = """
...Y....
.B...B..
Y.Y.B.Y.
.B.Y.B..
B.Y.B.Y.
.Y.B.B..
B...Y...
....B...
"""
COFFEE = """
..Y..Y..
...Y..Y.
.BBBBB..
.BRRRBBB
.BBBBB.B
.BBBBBBB
..BBB...
.YYYYY..
"""
FRIES = """
.Y.Y.Y..
.YYYYY..
.YYYYYY.
RRRRRRR.
RYRRRYR.
.RRRRR..
.RRRRR..
..RRR...
"""
ICECREAM = """
..RRR...
.RRBRR..
.RRRRR..
.BBBBB..
..YYY...
..YYY...
...Y....
...Y....
"""
SPATULA = """
.YYYY...
.Y.Y.Y..
.YYYYY..
..YYY...
...Y....
...B....
...B....
...BB...
"""
SPARK_A = """
...Y....
...Y....
YY...YY.
...Y....
...Y....
........
........
........
"""
SPARK_B = """
.Y...Y..
..Y.Y...
........
..Y.Y...
.Y...Y..
........
........
........
"""
ARROW = """
...YY...
...YY...
...YY...
...YY...
.YYYYYY.
..YYYY..
...YY...
........
"""

# --- ingredients: 16 px x 2 rows ------------------------------------------
PIECES = {   # type letter -> (name, two rows)
    'T': ("TOP BUN",    [".YYYBYYYYBYYYBY.", "YYYYYYYYYYYYYYYY"]),
    'L': ("LETTUCE",    ["BBBBBBBBBBBBBBBB", "B.B.B.B.B.B.B.B."]),
    'C': ("CHEESE",     ["YYYYYYYYYYYYYYYY", ".Y...Y...Y...Y.."]),
    'M': ("MEAT",       [".RRBRRRBRRRBRRR.", "RRRRRRRRRRRRRRRR"]),
    'O': ("TOMATO",     ["RRRR.RRRR.RRRR.R", "RYRR.RYRR.RYRR.R"]),
    'B': ("BOTTOM BUN", ["YYYYYYYYYYYYYYYY", ".YYYYYYYYYYYYYY."]),
}
PIECE_ORDER = "TLCMOB"
