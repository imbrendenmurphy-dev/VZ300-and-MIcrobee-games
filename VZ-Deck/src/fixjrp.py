import re,sys,bplug
from asm import assemble
fmt=sys.argv[1]; FILES=('plib.asm','fmt_%s.asm'%fmt)
for it in range(60):
    try: bplug.build(fmt); break
    except Exception as e:
        m=re.match(r'line (\d+): JR range',str(e))
        if not m: raise
        rate=0
        src='KSTEP EQU 1\n'+open('plib.asm').read()+'\n'+open('fmt_%s.asm'%fmt).read()
        line=src.split('\n')[int(m.group(1))-1]
        fixed=False
        for fn in FILES:
            t=open(fn).read()
            if line+'\n' in t:
                t=t.replace(line+'\n',line.replace('JR ','JP ',1)+'\n'); open(fn,'w').write(t); fixed=True; print('fixed',line.strip(),fn)
        assert fixed,line
