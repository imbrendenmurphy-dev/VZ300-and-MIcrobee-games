import sys
from zasm import assemble
from raytables import fill, mzt

MAP=["2222222222222222",
     "2......2.......2",
     "2..3...2..6..6.2",
     "2......5.......2",
     "2..3...2..6..6.2",
     "2......2.......2",
     "2222522222.22222",
     "1..............1",
     "1..4......4....1",
     "1..............1",
     "1111511111.11111",
     "3......3.......3",
     "3..6...5...4...3",
     "3......3.......3",
     "3......3.......3",
     "3333333333333333"]

def sub(t,a,b): return [r.replace(a,b) for r in t]
brick=["KKKKKKKK","RRRRKRRR","RRRRKRRR","RRRRKRRR","KKKKKKKK","RKRRRRRR","RKRRRRRR","RKRRRRRR"]
stone=["CCCCCCCC","WWWCWWWW","WWWCWWWW","WWWCWWWW","CCCCCCCC","WWWWWWCW","WWWWWWCW","WWWWWWCW"]
tech =["GGGGGGGG","GKKKKKKG","GKYGGYKG","GKGGGGKG","GKGGGGKG","GKYGGYKG","GKKKKKKG","GGGGGGGG"]
wood =["YYRYYYRY","YYRYYYRY","YYRYRYRY","YYRYYYRY","YYRYYYRY","YRRYYYRY","YYRYYYRY","YYRYYYRY"]
door =["WWWWWWWW","WCCCCCCW","WCWWWWCW","WCCCCCCW","WCCCCYCW","WCCCCCCW","WCCCCCCW","WWWWWWWW"]
tile =["MMWWMMWW","MMWWMMWW","WWMMWWMM","WWMMWWMM","MMWWMMWW","MMWWMMWW","WWMMWWMM","WWMMWWMM"]
TEXS=[brick, sub(brick,'R','M'),
      stone, sub(sub(stone,'C','K'),'W','C'),
      tech,  sub(sub(sub(tech,'G','x'),'K','G'),'x','K'),
      wood,  sub(sub(sub(wood,'Y','x'),'R','Y'),'x','R'),
      door,  sub(sub(sub(door,'W','x'),'C','W'),'x','C'),
      tile,  sub(tile,'W','K')]

src=fill(open('mzray.asm').read(),[int(ch) if ch!='.' else 0 for r in MAP for ch in r],TEXS)
open('mzray_full.asm','w').write(src)
lo,data,sym=assemble(src)
exe=sym['start']
open('MZRAY.MZT','wb').write(mzt(b'MZRAY BENCH',lo,data,exe))
open('mzray.sym','w').write('\n'.join('%-14s %04X'%(k,v) for k,v in sorted(sym.items(),key=lambda x:x[1])))
print('load %04X size %d end %04X exec %04X'%(lo,len(data),lo+len(data)-1,exe))
