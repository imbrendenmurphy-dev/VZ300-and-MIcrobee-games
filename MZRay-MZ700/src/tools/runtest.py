import sys,time
from mzemu import MZ
d=open('MZRAY.MZT','rb').read()
h=d[:128]; data=d[128:]
load=int.from_bytes(h[20:22],'little'); exe=int.from_bytes(h[22:24],'little')
sym={l.split()[0]:int(l.split()[1],16) for l in open('mzray.sym')}
m=MZ(load,data,exe)
t0=time.time()
# shot mid-test 1
m.run_until(sym['ba_f'],50_000_000); m.run_t(70938*6); m.shot('shot_bench1.png')
ok=m.run_until(sym['wait_mode'],2_000_000_000)
print('reached results',ok,'T=%d  %.1fs'%(m.cpu.t,time.time()-t0))
r=sym['results']; print('fields per 32 frames:',[m.mem[r+2*i]|m.mem[r+2*i+1]<<8 for i in range(4)])
m.shot('shot_results.png')
