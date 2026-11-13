import sys,re
from asm import assemble
CPU=3546900.0; TLOOP=188
BSS=[('count',1),('cur',1),('top',1),('lastkey',1),('rpt',1),('lz',1),('pathlen',1),('wptr',2),('numv',3),('gap',1),('swapped',1),('depth',1),('restore',1),('joyon',1),('path',128),('dstack',128),
 ('fsize',2),('pname',11),('secs',1),('ppq',2),('ntrk',1),('fend',2),('trk',128),('cend',2),('ntab',30),('vce',24),('pha0',2),('pha1',2),('pha2',2),('mind',2),('seqnow',1),('dreq',1),('evn',1),('stopf',1),('armed',1),('wfrac',1),('fcnt',1),('dshow',1),('gottitle',1),('lastpc',1),('nchg',1),('fl',2),('tempo',3),('newmin',2),('anyon',1),('tbase',2),('cstat',1),('mtype',1),('loseq',1),('hiseq',1),('mipit',1),('miseq',1),('sv_p',1),('sv_s',1),('sv_v',1),('t_semi',1),('t_oct',1),('pr0',4),('wt0',2),('wt2',1),('spsave',2),('nseed',2),('mc0',4),('pp0',4),('ipt',3),('blen',4),('debt',1),('vmode',1),('ismod',1),('resel',1),('pausef',1),('viewf',1),('fx',1),('sclev',1),('nsmp',1),('mhdr',2),('slen',1),('mord',2),('npat',1),('mstream',1),('clp',2),('nclt',1),('mcl',4),('mspeed',1),('pos',1),('mrow',1),('mbreak',1),('mend',1),('msmp',4),('mdur',4),('rowp',2),('rowpit',4),('rowsmp',4),('rf_off',1),('mr_ch',1),('mr_b2',1),('mr_b3',1),('mr_per',2),('mr_s',1),('mr_pit',1),('mr_dur',1),('p2t',2),('kwname',2),('kwkind',1),('sdrum',62),('db_old',1),('ceof',1),('strm',1),('cbendh',1),('cbaseh',1),('csec',2),('cendsec',2),('spos',3),('sidx',1),('slen3',3),('tcur',2),('tend',32),('tendo',32),('cendo',2),('climit',2),('nplug',1),('plugs',72),('shcl',6),('outmode',1),('omode',1),('andv',1),('xorv',1),('xorm',1),('tmulv',2),('lbase',1)]
def source(K):
    a=0x7C00; eq=[]
    for n,sz in BSS: eq.append('%s EQU 0x%04X'%(n,a)); a+=sz
    assert a<=0x7FC0,hex(a)
    for k,v in K.items(): eq.append('%s EQU %d'%(k,v))
    rate=CPU/TLOOP
    ft=','.join(str(int(round(440*2**((108+s-69)/12)*65536/rate))) for s in range(12))
    return '\n'.join(eq)+'\n'+open('shell.asm').read()+'\n'+open('player.asm').read()+'\nftab: DW '+ft+'\n'+open('modvis.asm').read()+'\n'
K=dict(TMUL=int(round(65536*CPU/1e6/TLOOP)),TMULP=int(round(65536*CPU/1e6/(TLOOP+6))),GRC=26,FRC=8,KICKF=1051,KICKS=6,KICKN=120,SNRN=250,HATN=50,KICKC=200,SNRC=200,HATC=40,ROLLC=23,TRKC=5,MODTRIM=10,REFC=240,TBH=0xA2)
if __name__=='__main__':
    import json,os
    if os.path.exists('consts.json'): K.update(json.load(open('consts.json')))
    code,sy=assemble(source(K),0x8000)
    assert sy['blk_src']<=0x9A00, hex(sy['blk_src'])
    assert sy['blk_end0']<=0x6800, hex(sy['blk_end0'])
    print('main end %04X  block end %04X'%(sy['blk_src'],sy['blk_end0']))
    hdr=b'  \x00\x00'+b'VZ-DECK'.ljust(17,b'\x00')+b'\xf1'+b'\x00\x80'
    open('out/SHELL.VZ','wb').write(hdr+code)
    json.dump({k:v for k,v in sy.items()},open('out/syms.json','w'))
    print('shell',len(code),'end %04X'%(0x8000+len(code)),K)
