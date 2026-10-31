"""Chapter 1 - THE EMBER HALLS.  4x3 screens of 32x15 cells.
Legend:  # wall (auto rim/face/rock)   . floor     ~ dust motes / drips
         T wall torch   E brazier flame   C crystal   c candle   u glow-mushrooms
         P pillar (vertical run)   S statue (2 tall)   A altar run   t tomb run
         m mosaic runner   w water   l luminous pool   b bones   r rubble  " debris
         o boulder   X rune (message)   D locked door   H hidden (breakable) wall
         d doorway   < stairs up (start)   > stairs down   Y magic seal (boss)
         L lava  Q bookshelf  O machinery  _ bridge  V the Ember
Entities: @ player start  K skeleton  B bat  s slime  G ghost  e eel  z drowned
          i imp  q magma slime  x spider   & the chapter boss
Items:    f ember staff  k key  g gem  p potion  h heart  n boots  j sunstone
          y ring of embers  a runeblade  M mana crystal
"""
from glyph import S, T, V, G, Y, B, R, W, C, M, O

CHAPTER = 1
NAME = 'THE EMBER HALLS'
START_MSG = "THE STAIR CRUMBLES BEHIND YOU"
MUSIC = ['temple', 'cave', 'crypt']

SCREENS = {
    (0, 0): dict(region='temple', css=1, title='THE DESCENT', rows=[
        '################################',
        '##<@#######T######T#############',
        '##.....................~.c..####',
        '##.b...########."####......g.###',
        '##.....########..####..X.....###',
        '####.##########..####..B...c.###',
        '####.##########..###############',
        '####.##########..###############',
        '#T.....o..####....T#############',
        '##........####.................#',
        '##.........r..........b.........',
        '##.......................o......',
        '######.....#####T####.....######',
        '################################',
        '################################'],
        msgs=["THE EMBER SLEEPS. WAKE IT."]),
    (1, 0): dict(region='temple', css=1, title='EMBER TEMPLE', rows=[
        "################################",
        "#######T#######EE#######T#######",
        "####.......S..AAAA..S.......####",
        "###........S...f....S........###",
        "###....P...P...mm...P...P....###",
        "###....P...P...mm...P...P....###",
        "##T............mm.....B.......T#",
        "###............mm............###",
        "###....P...P...mm...P...P....###",
        "###....P...P...mm...P...P....###",
        "...............mm...............",
        "..........B....mm...............",
        "###..b.....K...mm.........\"..###",
        "#####..........dd...........####",
        "###############dd###############"],
        msgs=[]),
    (2, 0): dict(region='library', css=1, title='THE SCRIPTORIUM', music='temple', rows=[
        "################################",
        "##T####T####T####T####T####T####",
        "##........................|M####",
        "##.QQQQQ.QQQQQ..X..QQQQQ.QQQQQ##",
        "##..........x...............p.##",
        "##.QQQQQ.QQQQQ.....QQQQQ.QQQQQ##",
        "##.......c..........c.......h.##",
        "##.QQQQQ.QQQQQ.AAA.QQQQQ.QQQQQ##",
        "##..............x.............##",
        "##.QQQQQ.QQQQQ.....QQQQQ.QQQQQ##",
        "..............................##",
        "...........x..................##",
        "##.QQQQQ.QQQQQ..g..QQQQQ.QQQQQ##",
        "##..c...........^........c....##",
        "################################"],
        msgs=["THE BUILDERS FED A FIRE BELOW"]),
    (1, 1): dict(region='cave', css=0, title='CISTERN OF TEARS', rows=[
        '###############..###############',
        '#######C#######..#######C#######',
        '###.............~............###',
        '###.u......................u.###',
        '###..........................###',
        '###...llllllllll.......s.....###',
        '###.~.llllllllll...C.........###',
        'H.X...llllllllll........o.....##',
        'H.....llllllllll.....s........##',
        '###...llllllllll......#####..###',
        '###...........u.......##k##..###',
        '###.....s.........C.........~.##',
        '###..........................###',
        '##########C############C########',
        '################################'],
        msgs=["THE WALL WEEPS WHERE TEARS POOL"]),
    (0, 1): dict(region='crypt', css=1, title='THE SEALED CRYPT', rows=[
        '################################',
        '#########T#######T#######T######',
        '######.......................###',
        '######.c.ttt..c.ttt..c.ttt...###',
        '######..............X........###',
        '######.......G.........p.....###',
        '######.c.ttt..c.ttt..c.ttt...###',
        '######..........................',
        '######..........................',
        '######.c.ttt..c.ttt..c.ttt...###',
        '######.......................###',
        '######..g...........~......h.###',
        '######.c.ttt..c.ttt..c.ttt...###',
        '########T####.#####T#######T####',
        '#############D##################'],
        msgs=["A WARDEN GUARDS THE DEEPER STAIR"]),
    (0, 2): dict(region='crypt', css=1, title="WARDEN'S HALL", rows=[
        '#############.##################',
        '########T####.####T#############',
        '####.........b..............####',
        '####...P.....P.....P........####',
        '####...P.....P.....P........####',
        '####........................####',
        '###T.........&..............T###',
        '####........................####',
        '####...P.....P.....P........####',
        '####...P.....P.....P........####',
        '####..b..............b......####',
        '####.........YYYY...........####',
        '####.........Y>XY...........####',
        '####.........YYYY...........####',
        '################################'],
        msgs=["BEYOND LIES THE DROWNED CITY..."]),
}

BOSS = dict(
    name="BONE WARDEN", size=2, hp=22, speed=20, shot=80, pattern=0, minion='bat', minion_every=360,
    shot_glyph=S(W, '.xx.'), pic='warden',
    glyphs=[[S(W, '.xxx'), S(W, 'xxx.'), S(R, 'xx.x'), S(R, 'x.xx')],
            [S(W, '.xxx'), S(W, 'xxx.'), S(R, 'x.xx'), S(R, 'xx.x')]])
