from mtest import *
KEYS['V']=(0xFB,5)
for fmt,src in (('pt3','../proj/VZ-Deck/release/DEMO.PT3'),('psg','/mnt/user-data/attachments/e53cae13-cb3c-5fe8-8a47-fe91113ecae5/0b1b1025-demo.psg'),('s3m','out/LONG.S3M'),('xm','out/DEMO.XM'),('vgm','out/LONG.VGM')):
    files={n:open('out/'+n,'rb').read() for n in ('VZDOS.VZ','SHELL.VZ','PLAY%s.VZ'%fmt.upper())}
    fn='T.'+fmt.upper(); files[fn]=open(src,'rb').read(); names=sorted(files)
    im=FatImg()
    for n,d in files.items(): im.addfile(2,n,d)
    im.finish(); m=boot(im); m.tsync=True; go(m,[(None,5)],maxsteps=40000000)
    go(m,tap('DOWN',names.index(fn))+tap('RET'),extra=150,maxsteps=10**10)
    while m.z.mem[0x7FDE]!=2: go(m,tap('V'),extra=10,maxsteps=10**10)
    go(m,[(None,60)],extra=1,maxsteps=10**10); v=bytes(m.z.mem[0x7000+5*32:0x7000+11*32]); print(fmt,"roll cells lit:",sum(1 for b in v if b>=0x80 and b&15), "of 192"); __import__("vzrender").render(bytes(m.z.mem[0x7000:0x7200])).save("../roll_%s.png"%fmt)
