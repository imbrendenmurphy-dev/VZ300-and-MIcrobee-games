import sys,json
from asm import assemble
CPU=3546900.0; AY=1773400.0
def tables():
    pt=[int(round(AY/16/(32.703195662574829*2**(n/12)))) for n in range(96)]
    vt=[int(round(v*a/15)) for v in range(16) for a in range(16)]
    th=[p+p//32 for p in pt]
    ct=[min(65535,int(round(8363*2**((k-23.5)/12)))) for k in range(48)]
    return 'ptab: DW '+','.join(map(str,pt))+'\nvoltab: DB '+','.join(map(str,vt))+'\npthr: DW '+','.join(map(str,th))+'\ncthr: DW '+','.join(map(str,ct))+'\n'
VARS=[('fsize',3),('secs',1),('srem',2),('sptr',2),('debt',1),('dreq',1),('nseed',2),('spsave',2),('pha0',2),('pha1',2),('pha2',2),
 ('vper',6),('vamp',6),('vton',6),('vstep',6),('vlast',6),('vnote',3),('blen',3),('dlast',3),('slast',3),('dnote',1),('dcnt2',1),('vmode',1),('rowflag',1),('rownum',1),('rownote',3),('rowinst',3),('dshow',1),('armed',1),('stopf',1),('omode',1),('andv',1),('xorv',1),('xorm',1),('ksl',2),('ksh',1),('lbase',1)]
FMT={'pt3':(open,[('ver',1),('delay',1),('npos',1),('patp',2),('dcnt',1),('posi',1),('nbase',1),('prnote',1),('prsld',2),('fcnt',8),('b0',1),('b1',1),('cursmp',1),('chA',40),('chB',40),('chC',40)]),
     's3m':(open,[('clt',1020),('clp',2),('nclt',1),('cursec',2),('rf_off',1),('foff',3),('fdst',2),('hdr',0x60),('nord',1),('nins',1),('npat',1),('speed',1),('tempo',1),('ords',256),('ipp',200),('ppp',512),('ii',1),('ibuf',0x50),('iinfo',400),('tcnt',1),('tacc',1),('pos',1),('ppos',1),('row',1),('rowp',2),('plen',2),('mend',1),('chg',1),('rowk',1),('brk',1),('jmp',1),('what',1),('rch',1),('rnote',1),('rins',1),('rvol',1),('rcmd',1),('rinfo',1),('seqc',1),('chnote',32),('chins',32),('chvol',32),('chdur',32),('chseq',32),('vhi',1),('vlo',1),('vmid',1),('vhic',1),('vloc',1),('best',1),('bestage',1),('kwname',2),('kwkind',1),('patb',0x2000)]),
     'xm':(open,[('clt',1020),('clp',2),('nclt',1),('cursec',2),('rf_off',1),('foff',3),('fdst',2),('hdr',80),('nord',1),('nch',1),('nins',1),('npat',1),('speed',1),('tempo',1),('ords',256),('ppp',1530),('ii',1),('istart',3),('shst',3),('ssum',3),('tmp4',4),('ibuf',40),('sbuf',40),('kbuf',32),('iinfo',516),('tcnt',1),('tacc',1),('pos',1),('ppos',1),('row',1),('prows',1),('rowp',2),('mend',1),('chg',1),('rowk',1),('brk',1),('jmp',1),('rch',1),('rnote',1),('rins',1),('rvol',1),('rcmd',1),('rinfo',1),('seqc',1),('chnote',32),('chins',32),('chvol',32),('chdur',32),('chseq',32),('vhi',1),('vlo',1),('vmid',1),('vhic',1),('vloc',1),('best',1),('bestage',1),('kwname',2),('kwkind',1),('patb',0x3000)]),
     'vgm':(open,[('clt',1020),('clp',2),('nclt',1),('cursec',2),('rf_off',1),('foff',3),('fdst',2),('hdr',0x40),('sclk',2),('kscale',2),('spos',3),('gd3',256),('att',4),('per',8),('nctl',1),('latch',1),('chg',1),('non',1),('wait',3),('mend',1),('pk',1),('p2t',2),('p2m',1),('sfrac',1),('ssec',1),('smin',1)]),
     'psg':(open,[('regs',16),('wcnt',2),('cool',3),('ison',3),('sfrac',1),('ssec',1),('smin',1),('p2t',2),('p2m',1),('pk',1)])}
def build(fmt,tloop=190.6):
    rate=CPU/tloop; K=int(round(65536*AY/16/rate)); KP=int(round(65536*AY/16/(CPU/(tloop+6))))
    src='KSTEP EQU %d\nKSTEPP EQU %d\nMAXCLT EQU 255\n'%(K,KP)+open('plib.asm').read()+'\n'+open('fmt_%s.asm'%fmt).read()+'\n'+(open('plib_rnd.asm').read() if fmt in ('s3m','xm','vgm') else '')+'\n'+tables()+'vars:\n'
    for n,sz in VARS+FMT[fmt][1]: src+='%s: DS %d\n'%(n,sz)
    src+='vars_end:\nfbuf EQU (vars_end+255)&0xFF00\n'
    code,sy=assemble(src,0xA000)
    code=code[:sy['vars']-0xA000]          # vars are cleared at run time: don't ship them
    hdr=b'  \x00\x00'+('PLAY'+fmt.upper()).encode().ljust(17,b'\x00')+b'\xf1'+b'\x00\xa0'
    open('out/PLAY%s.VZ'%fmt.upper(),'wb').write(hdr+code)
    json.dump(sy,open('out/play%s.json'%fmt,'w'))
    print(fmt,'code %d bytes, vars to %04X, file buffer %04X-F7FF (%d bytes)'%(len(code),sy['vars_end'],sy['fbuf'],0xF800-sy['fbuf']))
    return sy
if __name__=='__main__':
    for f in sys.argv[1:]: build(f)
