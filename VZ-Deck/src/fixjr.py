import re,build3,sys
FILES=('player.asm','modvis.asm','shell.asm')
from asm import assemble
for it in range(40):
    src=build3.source(build3.K)
    try: assemble(src,0x8000); print('ok after',it); break
    except Exception as e:
        m=re.match(r'line (\d+): JR range',str(e))
        if not m: raise
        line=src.split('\n')[int(m.group(1))-1]
        assert 'JR ' in line, line
        fixed=False
        for fn in FILES:
            t=open(fn).read()
            if t.count(line+'\n')>=1:
                # replace only occurrences that are out of range: replace all identical lines (safe: JP always works)
                t=t.replace(line+'\n',line.replace('JR ','JP ',1)+'\n'); open(fn,'w').write(t); fixed=True; print('fixed',line.strip(),'in',fn)
        assert fixed
