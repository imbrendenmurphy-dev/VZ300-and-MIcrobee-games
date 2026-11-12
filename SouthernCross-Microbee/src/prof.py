import sys, os, bisect
sys.path.insert(0, os.path.dirname(__file__))
import run as R
from z80emu import Bee, Z80
routines = ['keys','keytst','physics','tick','mkmatrix','clrback','clrbank','render','horizon','dser','vxform','addcol','mul168',
 'segment','nearclip','project','projdiv','vscale','clipdraw','search','outcode','near1','small','drawline','slopediv','xmloop','ymloop','panel','pdec','flip','timing','neghl','mulw','clampb','sincos','scale02','add24','sdiv168','mul16u8','rdvec','mkgrid','reticle']
addrs = sorted((R.syms[n], n) for n in routines)
keys_ = [a for a,_ in addrs]
m = Bee(); cpu = Z80(m)
data = open('build/SCROSS.COM','rb').read(); m.ram[0x100:0x100+len(data)] = data
hist = {}
frames = 0; flip = R.syms['flip']; t0=None
nfr = int(sys.argv[1]) if len(sys.argv)>1 else 3
keys = sys.argv[2] if len(sys.argv)>2 else ''
K = {'Q':17,'A':1,'O':15,'P':16,'T':20,'G':7,'R':18,'F':6,' ':55}
m.keys = set(K[c] for c in keys)
while frames < nfr:
    if cpu.pc == flip:
        frames += 1
        if frames == 2: hist = {}; t0 = cpu.t
    pc = cpu.pc; t = cpu.t
    cpu.step()
    i = bisect.bisect_right(keys_, pc) - 1
    n = addrs[i][1] if i >= 0 else '?'
    hist[n] = hist.get(n,0) + cpu.t - t
tot = cpu.t - t0
nfr = 2; print('per frame T =', tot)
for n,v in sorted(hist.items(), key=lambda x:-x[1])[:25]:
    print('%-10s %8d  %5.1f%%' % (n, v//(nfr-1), 100*v/tot))
