import subprocess,sys
inv=sys.argv[1] if len(sys.argv)>1 else '0'
sym={l.split()[1]:int(l.split()[0],16) for l in open('build/empires.sym')}
def pk(n,k=1): return "peek %04X %d"%(sym[n],k)
L=["serinv %s"%inv,"frames 25","key 3 1","frames 3","key 3 0","frames 250","key 33 1","frames 6","key 33 0","frames 30","key 52 1","frames 6","key 52 0","frames 1500",
   pk('curx',2),pk('tool')]
L+=["mouse 30 0 0 0","frames 4"]*4+[pk('ms_b1',3),pk('curx',2)]
L+=["mouse -40 25 0 0","frames 4"]*3+[pk('curx',2)]
L+=["mouse 0 0 0 1","frames 6","mouse 0 0 0 0","frames 6",pk('tool')]
L+=["mouse 0 0 1 0","frames 6","mouse 0 0 0 0","frames 30",pk('nbld')]
r=subprocess.run(['tools/beeemu','build/EMPIRES.COM'],input='\n'.join(L)+'\n',capture_output=True,text=True)
print('polarity',inv,'::',' | '.join(l.split(':',1)[1] for l in r.stderr.split('\n') if ':' in l and 'PC' not in l and 'callt' not in l))
