# HOPPY 2 - pixel art definitions.  '.' = transparent, g y b r = colours 0..3
# (CSS0: g green, y yellow, b blue, r red.  CSS1: buff, cyan, magenta, orange)

FROG = {
 'up': [
  ".yr..ry.",
  "rrrrrrrr",
  ".rryyrr.",
  ".rrrrrr.",
  "rr....rr",
  "r......r"],
 'upj': [
  ".yr..ry.",
  "rrrrrrrr",
  ".rryyrr.",
  "..rrrr..",
  ".r....r.",
  "r......r"],
 'right': [
  "r...rr..",
  ".rrrrryr",
  "rrryyrrr",
  "rrryyrrr",
  ".rrrrryr",
  "r...rr.."],
 'rightj': [
  "....rr..",
  "rrrrrryr",
  "..ryyrrr",
  "..ryyrrr",
  "rrrrrryr",
  "....rr.."],
 'squash': [
  "r..r..r.",
  ".rryrrr.",
  "rrryyrrr",
  ".rrryrr.",
  "r..r..rr",
  "........"],
 'squash2': [
  "........",
  "r.r..r.r",
  ".rryyrr.",
  "rrryyrrr",
  ".r.r..r.",
  "........"],
 'ring1': [
  "........",
  "..yyyy..",
  ".y.rr.y.",
  ".y.rr.y.",
  "..yyyy..",
  "........"],
 'ring2': [
  ".yyyyyy.",
  "y......y",
  "y......y",
  "y......y",
  "y......y",
  ".yyyyyy."],
 'ring3': [
  "y.y..y.y",
  "........",
  "y......y",
  "y......y",
  "........",
  "y.y..y.y"],
 'faint': [
  "r......r",
  "rr....rr",
  ".rrrrrr.",
  ".rryyrr.",
  "rrrrrrrr",
  ".yr..ry."],
 'angel': [
  "..yyyy..",
  ".y.rr.y.",
  "rrrrrrrr",
  ".rryyrr.",
  "r.rrrr.r",
  "........"],
}
HOPPINA = [
  ".b.rr.b.",
  "yyyrryyy",
  ".yyyyyy.",
  ".yyyyyy.",
  "yy....yy",
  "y......y"]
FLY = [
  "........",
  ".yy..yy.",
  "..ybby..",
  "...bb...",
  "..b..b..",
  "........"]
FLY2 = [
  "........",
  "........",
  "yyybbyyy",
  "...bb...",
  "..b..b..",
  "........"]
PICK = {
 'bubble': [
  "..gggg..",
  ".gy...g.",
  "g.y....g",
  "g......g",
  ".g....g.",
  "..gggg.."],
 'snail': [
  "y.y.....",
  ".y..rrr.",
  ".y.ryyyr",
  ".y.ryryr",
  ".yyyrrr.",
  "..yyyyyy"],
 'star': [
  "...y....",
  "..yyy...",
  "yyyryyy.",
  ".yyyyy..",
  ".yy.yy..",
  "y.....y."],
 'heart': [
  ".rr.rr..",
  "ryrrrrr.",
  "rrrrrrr.",
  ".rrrrr..",
  "..rrr...",
  "...r...."],
}
SNAKE = [
  "................",
  ".yy....yy....b..",
  "y..y..y..y..yyy.",
  "....yy....yy.yyy",
  "...........r.r..",
  "................"]
SNAKE2 = [
  "................",
  "...yy....yy.....",
  "..y..y..y..y.yb.",
  "yy....yy....yyyy",
  "............yrr.",
  "...........r...r"]
BUBBLE_RING = [
  "..bbbbbb..",
  ".b......b.",
  "b........b",
  "b........b",
  "b........b",
  "b........b",
  ".b......b.",
  "..bbbbbb.."]

# ---- lane objects (drawn facing RIGHT; mirrored automatically for left lanes)
VEH = {
 'car': [
  "................",
  ".....bbbbbb.....",
  "....bb.bb.bb....",
  ".yyyyyyyyyyyyyy.",
  "yyyyyyyyyyyyyyyy",
  "..rrr......rrr.."],
 'beetle': [
  "............",
  "...rrrrr....",
  "..rr.rr.r...",
  ".rrrrrrrrry.",
  "rrrrrrrrrrrr",
  "..bb....bb.."],
 'racer': [
  "................",
  "rr....bbbb......",
  "rrrrrrrrrrrrrrr.",
  "ryyyyyyyyyyyyyyy",
  "rrrrrrrrrrrrrrr.",
  ".bb........bb..."],
 'truck': [
  "............................",
  "bbbbbbbbbbbbbbbbbbb.yyyy....",
  "byyybyyybyyybyyyb.b.y..yy...",
  "bbbbbbbbbbbbbbbbbbbyyyyyyyy.",
  "bbbbbbbbbbbbbbbbbbbyyyyyyyyy",
  "..rr..rr.......rr....rr..r.."],
 'tractor': [
  "................",
  "..r.....bbbb....",
  "..r.....b..byy..",
  "..yyyyyyybbbyyy.",
  ".rrrr.yyrrrryyyy",
  "rr.yrr..rr.yrrr."],
 'dozer': [
  "....................",
  "....bbbbb.......yy..",
  "....b...b.......yy..",
  ".bbbbbbbbbbbbbbbyy..",
  "b..rrrrrrr..b..byyy.",
  "..ry.y.y.yr.....yyyy"],
 'bus': [
  "................................",
  "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrr..",
  "rbbrbbrbbrbbrbbrbbrbbrbbrbbrbbr.",
  "rrrrrrrrrrrrrrrrrrrrrrrrrrrrrrry",
  "ryyyyyyyyyyyyyyyyyyyyyyyyyyyyyyr",
  "...bbb..........bbb.......bbb..."],
}
TURTLE = {
 'up': [
  "........",
  ".y...y..",
  "gggggg..",
  "gyggyggy",
  "gggggg..",
  ".y...y.."],
 'warn': [
  "........",
  ".y...y..",
  "gggggg..",
  "grggrggy",
  "gggggg..",
  ".y...y.."],
 'half': [
  "........",
  "........",
  ".bggggb.",
  "bggggggb",
  ".bggggb.",
  "........"],
 'down': [
  "........",
  "...y....",
  "........",
  "..y..y..",
  "........",
  "....y..."],
}
CROC = [
  "................................",
  "......y.y.y.y.y.y......r........",
  "gg..ggggggggggggggggggggggggg...",
  "ggggggggggggggggggggggggyyyyyyy.",
  "..ggggggggggggggggggggggggggggg.",
  "......g...g........g...g........"]
CROC_OPEN = [
  "................................",
  "......y.y.y.y.y.y......r.ggggg..",
  "gg..ggggggggggggggggggggggy.y.y.",
  "gggggggggggggggggggggggg........",
  "..gggggggggggggggggggggggy.y.y..",
  "......g...g........g...ggggg...."]
LILY = [
  "........",
  "..gggg..",
  ".gggrgg.",
  ".gg.ggg.",
  "..gggg..",
  "........"]
LILYB = [  # lily used in home bay
  "........",
  ".gggggg.",
  "ggggggg.",
  "ggg.ggg.",
  ".gggggg.",
  "........"]

# backgrounds: 32 px wide, 6 rows (opaque)
BG = {
 'grass': [
  "gggggggggggggggggggggggggggggggg",
  "ggyggggggggggrgggggggggyggggggggg"[:32],
  "gyrygggggggggggggggggggggggggrgg",
  "ggyggggggggggggggyggggggggggrgrg",
  "ggggggggggrggggggyrggggggggggrgg"[:32],
  "gggggggggggggggggggggggggggggggg"],
 'start': [
  "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy",
  "gggggggggggggggggggggggggggggggg",
  "gggyggggggggrggggggggyggggggrggg",
  "ggyrygggggggggggggggyrygggggggggg"[:32],
  "gggygggggggggggggggggyggggggggggg"[:32],
  "gggggggggggggggggggggggggggggggg"],
 'median': [
  "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy",
  "gggggggggggggggggggggggggggggggg",
  "ggrggggggggyggggggggggrgggggyggg",
  "gyrygggggggggggggrggggggggggggggg"[:32],
  "ggrggggggggggggggggggggggggggggg",
  "yyyyyyyyyyyyyyyyyyyyyyyyyyyyyyyy"],
 'road': [
  "bbbbbb..........bbbbbb..........".replace('.','g'),
  "gggggggggggggggggggggggggggggggg",
  "gggggggggggggggggggggggggggggggg",
  "gggggggggggggggggggggggggggggggg",
  "gggggggggggggggggggggggggggggggg",
  "gggggggggggggggggggggggggggggggg"],
 'roadk': [   # first road lane (kerb above)
  "rgrgrgrgrgrgrgrgrgrgrgrgrgrgrgrg",
  "gggggggggggggggggggggggggggggggg",
  "gggggggggggggggggggggggggggggggg",
  "gggggggggggggggggggggggggggggggg",
  "gggggggggggggggggggggggggggggggg",
  "gggggggggggggggggggggggggggggggg"],
 'water': [
  "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "bbbbbbbbbbbgbbbbbbbbbbbbbbbbbbbb",
  "bbbbbbbbbbbbbbbbbbbbbbbbbbbgbbbb",
  "bbbbbgbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"],
 'water2': [
  "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "bbbbbbbbbbbbbbbbbbgbbbbbbbbbbbbb",
  "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "bbgbbbbbbbbbbbbbbbbbbbbbbbbbbbbb",
  "bbbbbbbbbbbbbbbbbbbbbbbbbgbbbbbb",
  "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"],
 'blank': ["g"*32]*6,
 'sky': ["b"*32]*6,
}

def log(n):
    w=n*8
    rows=["."*w]
    import random
    rnd=random.Random(n)
    for r in range(4):
        s=""
        for x in range(w):
            if x==0: s+= 'r' if r in(1,2) else ('y' if r in (0,3) else 'r')
            elif x==w-1: s+='y' if r in (1,2) else '.'
            elif r==0 or r==3: s+='y'
            else: s+= 'r' if rnd.random()<0.22 else 'y'
        rows.append(s)
    rows[1]='.'+rows[1][1:]; rows[4]='.'+rows[4][1:]
    rows.append("."*w)
    return rows

BAYCROC_PEEK = [
  "........",
  "........",
  "........",
  ".ry..yr.",
  "gggggggg",
  "........"]
BAYCROC = [
  "gyy..yyg",
  "gry..yrg",
  "gggggggg",
  "y.y..y.y",
  ".gggggg.",
  "........"]
SMOKE = [
  ".y.",
  "yyy",
  ".y."]
