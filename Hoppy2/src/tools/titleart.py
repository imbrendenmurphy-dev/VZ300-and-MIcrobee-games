# home row and title art
BAYS=[16,40,64,88,112]
def _home():
    rows=[]
    hedge=["rgggygggrggggygg", "ggygggrgggygggrg", "gggggggggggggggg", "grggygggggrggygg", "gggggggggggggggg","yyyyyyyyyyyyyyyy"]
    for r in range(6):
        s=(hedge[r]*8)[:128]
        s=list(s)
        for c in BAYS:
            for x in range(c-6,c+6):
                if r==5: s[x]='b'
                elif r==0: s[x]='g' if x in(c-6,c+5) else 'b'
                else: s[x]='b'
        rows.append("".join(s))
    return rows
HOME=_home()
SPRITES={}
MASKED={}
OPAQUE={}

# ---------------- big logo letters (7x7 base, x2 scale, outlined)
_BASE = {
'H': ["##...##","##...##","##...##","#######","##...##","##...##","##...##"],
'O': [".#####.","##...##","##...##","##...##","##...##","##...##",".#####."],
'P': ["######.","##...##","##...##","######.","##.....","##.....","##....."],
'Y': ["##...##","##...##",".##.##.","..###..","..##...",".##....","##....."],
'2': [".#####.","##...##",".....##","..####.",".##....","##.....","#######"],
}
def _big(ch, fill, line, shine):
    b=_BASE[ch]
    W,H=16,16
    g=[['.']*W for _ in range(H)]
    for y in range(7):
        for x in range(7):
            if b[y][x]=='#':
                for dy in range(2):
                    for dx in range(2):
                        g[1+2*y+dy][1+2*x+dx]='F'
    out=[['.']*W for _ in range(H)]
    for y in range(H):
        for x in range(W):
            if g[y][x]=='F':
                out[y][x]=fill
            else:
                for dy in(-1,0,1):
                    for dx in (-1,0,1):
                        yy,xx=y+dy,x+dx
                        if 0<=yy<H and 0<=xx<W and g[yy][xx]=='F': out[y][x]=line
    # shine: top-left fill pixels of each blob row 1..2
    for y in range(H):
        for x in range(W):
            if out[y][x]==fill and y>0 and out[y-1][x]==line and (x+y)%3==0: out[y][x]=shine
    return ["".join(r) for r in out]
for ch in "HOPY":
    SPRITES['spr_L'+ch]=_big(ch,'y','r','g')
SPRITES['spr_L2']=_big('2','r','y','b')


HOPPYBIG = [
 "....yyyy........yyyy....",
 "...yybbyy......yybbyy...",
 "...yybbyy......yybbyy...",
 "...ryyyyrrrrrrrryyyyr...",
 "..rrrrrrrrrrrrrrrrrrrr..",
 ".rrrrrrrrrrrrrrrrrrrrrr.",
 ".rrrrrrrrrrrrrrrrrrrrrr.",
 ".rrryrrrrrrrrrrrrrryrrr.",
 ".rrrryyyyyyyyyyyyyyrrrr.",
 "..rrrrrrrrrrrrrrrrrrrr..",
 "..rrryyyyyyyyyyyyyyrrr..",
 ".rrryyyyyyyyyyyyyyyyrrr.",
 "rrrryyyyyyyyyyyyyyyyrrrr",
 "rr.ryyyyyyyyyyyyyyyyr.rr",
 "r..rrrrrrrrrrrrrrrrrr..r",
 "..rr.rr..........rr.rr..",
 ".rrr.rrr........rrr.rrr.",
]
def _blink(a):
    a=list(a); a[1]="...yyyyyy......yyyyyy..."; a[2]="...rrrrrr......rrrrrr..."
    return a
def _croak(a):
    a=list(a)
    a[9] ="..rrryyyyyyyyyyyyyyrrr..";a[10]=".rryyyyyyyyyyyyyyyyyyrr.";a[11]="rryyyyyyyyyyyyyyyyyyyyrr"
    return a
def _gulp(a):
    a=list(a); a[8]=".rrrbbbbbbbbbbbbbbbbrrr."; a[7]=".rrrbrrrrrrrrrrrrrrbrrr."
    return a
def _wide(a):
    a=list(a); a[0]="...yyyyyy......yyyyyy..."; a[1]="..yyybbyyy....yyybbyyy.."; a[2]="..yyybbyyy....yyybbyyy.."
    return a
SPRITES['spr_hop']=HOPPYBIG
SPRITES['spr_hopb']=_blink(HOPPYBIG)
SPRITES['spr_hopc']=_croak(HOPPYBIG)
SPRITES['spr_hopg']=_gulp(HOPPYBIG)
SPRITES['spr_hopw']=_wide(HOPPYBIG)
SPRITES['spr_sun']=[
 "....yyyy....",
 "..yyyyyyyy..",
 ".yyyyyyyyyy.",
 "yyyyyyyyyyyy",
 "yyyyyyyyyyyy",
 ".yyyyyyyyyy.",
 "..yyyyyyyy..",
 "....yyyy...."]

SPRITES['spr_pad']=[
 "....gggggggggggggggg....",
 "..ggggggggggggggggggggg.",
 "gggggggggggg..gggggggggg",
 "..gggggggggggggggggggg..",
 ]
SPRITES['spr_dozer']=[
 "....................",
 "....bbbbb.......yy..",
 "....b...b.......yy..",
 ".bbbbbbbbbbbbbbbyy..",
 "b..rrrrrrr..b..byyy.",
 "..ry.y.y.yr.....yyyy"]
SPRITES['spr_dozer2']=[
 "....................",
 "....bbbbb.......yy..",
 "....b...b.......yy..",
 ".bbbbbbbbbbbbbbbyy..",
 "b..rrrrrrr..b..byyy.",
 "..r.y.y.y.r.....yyyy"]
SPRITES['spr_mini']=[".y.y.","rrrrr",".rrr.","r...r"]
SPRITES['spr_snailt']=["y.y.....","yy.rrr..",".yryyyr.","yyyrrry.",".yyyyyyy"]


# clouds as lane objects (masked, byte aligned) on sky
MASKED['o_cloud1']=[
 "........................",
 "......yyyy..............",
 "...yyyyyyyyyy...yyy.....",
 ".yyyyyyyyyyyyyyyyyyyyy..",
 "..yyyyyyyyyyyyyyyyyy....",
 "........................"]
MASKED['o_cloud2']=[
 "................",
 "....yyy.........",
 "..yyyyyyyyy.....",
 "yyyyyyyyyyyyyy..",
 "................",
 "................"]
