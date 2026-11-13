import sys, subprocess, struct, bisect
sys.path.insert(0,'.'); sys.path.insert(0,'../tools')
import build_race as B
SUB=sys.argv[1] if len(sys.argv)>1 else '@@'
B.HALF_INIT = 1
src,_ = B.source(); asm, org, data, vz = B.assemble(src, 'RACE3D.VZ')
subprocess.run([B.EMU, vz, str(70630*50*20), '--pchist','hist.bin','--memdump','mem_game.bin'], capture_output=True, stdin=subprocess.DEVNULL)
h = struct.unpack('<65536Q', open('hist.bin','rb').read())
m=open('mem_game.bin','rb').read(); w=lambda n: m[asm.sym[n]]|m[asm.sym[n]+1]<<8
frames=w('FRAMES')
labels=sorted((v,k) for k,v in asm.sym.items() if 0x8000<=v<0xA400 and ('.' not in k or k.startswith(SUB)))
addrs=[a for a,_ in labels]; agg={}
for pc in range(0x8000,0xA400):
    if h[pc]: n=labels[bisect.bisect_right(addrs,pc)-1][1]; agg[n]=agg.get(n,0)+h[pc]
for k,v in sorted(agg.items(), key=lambda x:-x[1])[:200]:
    print(f'  {k:14s} {v/frames:9,.0f} T/frame')
