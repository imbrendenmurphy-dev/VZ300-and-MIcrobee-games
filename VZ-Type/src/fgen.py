# front-end data: logo, 3x5 font, strings, tunes, period table (all original)
import math
out=[]
def emit(s): out.append(s)
def db(l,per=16):
    for i in range(0,len(l),per): emit('\tdb '+','.join('$%02x'%(v&255) for v in l[i:i+per]))
LOGO={
'V':["11...11","11...11","11...11","11...11",".11.11.",".11.11.","..111..","...1..."],
'Z':["1111111","1111111","....11.","...11..","..11...",".11....","1111111","1111111"],
'-':[".......",".......",".......",".11111.",".11111.",".......",".......","......."],
'T':["1111111","1111111","..111..","..111..","..111..","..111..","..111..","..111.."],
'Y':["11...11","11...11",".11.11.","..111..","..111..","..111..","..111..","..111.."],
'P':["111111.","1111111","11...11","1111111","111111.","11.....","11.....","11....."],
'E':["1111111","1111111","11.....","111111.","111111.","11.....","1111111","1111111"]}
W=64; H=8
pix=[[0]*W for _ in range(H)]
x=4
for ch in "VZ-TYPE":
    g=LOGO[ch]
    for y in range(8):
        for i in range(7):
            if g[y][i]=='1': pix[y][x+i]=1
    x+=8
cells=[]
for cr in range(4):
    for cc in range(32):
        q=0
        if pix[cr*2][cc*2]: q|=8
        if pix[cr*2][cc*2+1]: q|=4
        if pix[cr*2+1][cc*2]: q|=2
        if pix[cr*2+1][cc*2+1]: q|=1
        cells.append(q)

F={' ':["...","...","...","...","..."],'!':[".1.",".1.",".1.","...",".1."],'-':["...","...","111","...","..."],
'.':["...","...","...","...",".1."],'/':["..1","..1",".1.","1..","1.."],':':["...",".1.","...",".1.","..."],
'0':["111","1.1","1.1","1.1","111"],'1':[".1.","11.",".1.",".1.","111"],'2':["111","..1","111","1..","111"],
'3':["111","..1",".11","..1","111"],'4':["1.1","1.1","111","..1","..1"],'5':["111","1..","111","..1","111"],
'6':["111","1..","111","1.1","111"],'7':["111","..1",".1.",".1.",".1."],'8':["111","1.1","111","1.1","111"],
'9':["111","1.1","111","..1","111"],
'A':["111","1.1","111","1.1","1.1"],'B':["11.","1.1","11.","1.1","11."],'C':["111","1..","1..","1..","111"],
'D':["11.","1.1","1.1","1.1","11."],'E':["111","1..","11.","1..","111"],'F':["111","1..","11.","1..","1.."],
'G':["111","1..","1.1","1.1","111"],'H':["1.1","1.1","111","1.1","1.1"],'I':["111",".1.",".1.",".1.","111"],
'J':["..1","..1","..1","1.1","111"],'K':["1.1","1.1","11.","1.1","1.1"],'L':["1..","1..","1..","1..","111"],
'M':["1.1","111","111","1.1","1.1"],'N':["11.","1.1","1.1","1.1","1.1"],'O':["111","1.1","1.1","1.1","111"],
'P':["111","1.1","111","1..","1.."],'Q':["111","1.1","1.1","111","..1"],'R':["111","1.1","11.","1.1","1.1"],
'S':["111","1..","111","..1","111"],'T':["111",".1.",".1.",".1.",".1."],'U':["1.1","1.1","1.1","1.1","111"],
'V':["1.1","1.1","1.1","1.1",".1."],'W':["1.1","1.1","111","111","1.1"],'X':["1.1","1.1",".1.","1.1","1.1"],
'Y':["1.1","1.1",".1.",".1.",".1."],'Z':["111","..1",".1.","1..","111"]}
fb=[]
for c in range(32,91):
    g=F.get(chr(c),F[' '])
    for r in g:
        v=0
        for k,ch in enumerate(r):
            if ch=='1': v|=0x80>>k
        fb.append(v)
emit('font35:'); db(fb)
def S(name,txt): emit('%s: db "%s",0'%(name,txt))
S('s_sub','A VZ300 SHOOT-EM-UP')
S('s_hi','HI SCORE ')
S('s_press','PRESS FIRE OR SPACE')
S('s_keys','QAOP MOVE  M POD  H PAUSE')
S('s_hof','HALL OF FAME')
S('s_howto','HOW TO PLAY')
emit('help_txt:')
for t in ['HOLD FIRE TO CHARGE THE BEAM','SHOOT CARRIERS FOR CAPSULES','CAPSULES ARM AND UPGRADE POD','M Z OR ARM LAUNCHES THE POD','H PAUSE  RETURN QUITS TO TITLE']:
    emit('\tdb "%s",0'%t)
emit('\tdb 0')
S('s_stage','STAGE 1')
S('s_ready','GET READY')
S('s_game','GAME')
S('s_over','OVER')
S('s_great','NEW HIGH')
S('s_well','WELL DONE')
S('s_enter','ENTER YOUR INITIALS')
S('s_enter2','UP DOWN SELECT  FIRE OK')
S('s_cong1','THE CORE IS DESTROYED')
S('s_cong2','BUT THE HORDE RETURNS')
S('s_cong3','THE NEXT WAVE BEGINS')
msg=('VZ-TYPE ... EIGHT STAGES OF BIOMECHANICAL MAYHEM ... HOLD FIRE TO CHARGE YOUR BEAM, '
     'LAUNCH THE POD TO SHIELD YOUR SHIP OR SEND IT AHEAD TO CLEAR THE WAY ... '
     'RED CAPSULES SPREAD, BLUE CAPSULES LANCE, YELLOW CAPSULES CROSSFIRE ... '
     'WRITTEN FOR THE DICK SMITH VZ300 IN 2026 ... GOOD LUCK PILOT ...')
full=' '*32+msg+' '*32
# default hall of fame
emit('def_hi:')
for sc,nm in [(0x02,'VZT'),(0x01,'POD'),(0x00,'ACE'),(0x00,'ZAP'),(0x00,'DSE')]:
    pass
for b0,b1,nm in [(0x02,0x00,'VZT'),(0x01,0x50,'POD'),(0x01,0x00,'ACE'),(0x00,0x50,'ZAP'),(0x00,0x25,'DSE')]:
    emit('\tdb $%02x,$%02x,$00,"%s",0,0'%(b0,b1,nm))
# pitch table
R=3546900/122.0          # player loop rate (iterations per second)
pt1=[1]; pt2=[1]
for m in range(1,128):
    fr=440*2**((m-69)/12)
    pt1.append(max(2,min(255,round(R/fr))))        # pulse: one cycle per period
    pt2.append(max(1,min(255,round(R/(2*fr)))))    # square: toggle every period
emit('ptab1:'); db(pt1)
emit('ptab2:'); db(pt2)
# ---- tunes (original compositions). note names -> midi
NN={'C':0,'C#':1,'D':2,'D#':3,'E':4,'F':5,'F#':6,'G':7,'G#':8,'A':9,'A#':10,'B':11}
def n(s):
    if s in ('.','-',None): return 0
    name=s[:-1]; o=int(s[-1]); return 12*(o+1)+NN[name]
def tune(label,rows):
    emit(label+':')
    b=[]
    for (t,a,bb,d) in rows: b+=[t,n(a),n(bb),d]
    b.append(0); db(b)
E=3
# title theme (original): simple E minor riff, melody in octave 4, bouncing bass
mel=['E4','.','G4','.','A4','.','B4','A4',
     'G4','.','E4','.','D4','.','E4','.',
     'E4','.','G4','.','A4','.','B4','D5',
     'B4','.','A4','.','G4','.','A4','.',
     'C5','.','B4','.','A4','.','G4','A4',
     'B4','.','G4','.','E4','.','G4','.',
     'A4','.','G4','.','F#4','.','G4','A4',
     'B4','.','.','.','E4','.','.','.']
roots=['E2','E2','C3','D3','C3','E2','D3','E2']
def bassbar(r):
    up=r[:-1]+str(int(r[-1])+1)
    return [r,'.',up,'.',r,'.',up,r]
rows=[]
for rep in range(2):
    for bar in range(8):
        bl=bassbar(roots[bar])
        for k in range(8):
            m=mel[bar*8+k]
            if rep==1 and m!='.' and bar in (2,3,6): m=m  # same tune, kept simple
            rows.append((E,m,bl[k],1 if k in (0,4) else 0))
# a short break: bass and drums alone, then round again
for bar in range(2):
    r=['E2','D3'][bar]
    for k in range(8):
        rows.append((E,'.',r if k%2==0 else r[:-1]+str(int(r[-1])+1),1 if k in (0,2,4,6) else 0))
tune('tune_title',rows)
tune('tune_stage',[(E,'E4','E2',1),(E,'G4','.',0),(E,'B4','.',0),(E,'E4','B2',1),(E,'G4','.',0),(E,'B4','.',0),(12,'E5','E2',1),(6,'.','.',0)])
tune('tune_over',[(6,'E5','A3',1),(6,'D5','.',0),(6,'C5','F3',1),(6,'B4','.',0),(6,'A4','E3',1),(6,'G#4','.',0),(18,'A4','A2',1),(6,'.','.',0)])
tune('tune_clear',[(E,'G4','G2',1),(E,'B4','.',0),(E,'D5','D3',0),(E,'G5','.',1),(E,'.','.',0),(E,'D5','B2',0),(12,'G5','G2',1),(6,'.','.',0)])
# ---- mode(1) logo glyphs (original lettering, see logofont.py)
import logofont as LF
cmap={'.':0,'1':1,'2':2,'3':3}
bs=[]
for g in LF.GLYPHS:
    for r in g:
        r=r.ljust(16,'.')
        for b in range(4):
            v=0
            for k in range(4): v=(v<<2)|cmap[r[b*4+k]]
            bs.append(v)
emit('GLH equ %d'%LF.GLH)
emit('logo_gly:'); db(bs)
emit('logo_fcol:'); db(LF.FCOL)
S('s_trn_on','TRAINER MODE ON - NO HISCORES')
S('s_trn_off','PRESS T FOR TRAINER MODE')
S('s_fire','PRESS FIRE OR SPACE TO PLAY')
S('s_score','SCORE ')
S('s_trnover','TRAINER MODE - NOT RECORDED')
S('s_quit','X IN PAUSE QUITS THE GAME')
S('s_hi2','HIGH SCORE')
S('s_gameover','GAME OVER')
S('s_ent3','UP DOWN SELECT  FIRE OK')
S('s_ready2','GET READY PILOT')
open('fdata.inc','w').write('\n'.join(out)+'\n')
print('ok',len(out))
