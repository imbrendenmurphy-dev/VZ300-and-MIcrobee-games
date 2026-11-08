import run, bisect, mbee, sys
pp=run.boot()
S=pp.S
labs=sorted((v,k) for k,v in S.items() if v>=0x8000 and v<0xD400)
addrs=[l[0] for l in labs]
def lab(a):
    i=bisect.bisect_right(addrs,a)-1; return labs[i][1] if i>=0 else '?'
pp.run_frames(int(sys.argv[1]) if len(sys.argv)>1 else 0)
while pp.frames<20000:
    mbee.write_watch(pp,100,0x8700,S['code_end'])
    pp.run_ticks(3000)
    pc,a=mbee.write_hit(pp)
    if pc>=0: break
sp=pp.cpu.sp
print(pp.frames, lab(pc), hex(pc), hex(a))
print([ (hex(pp.peekw(sp+i)), lab(pp.peekw(sp+i))) for i in range(0,20,2)])
