import re,sys,bplug
fmt=sys.argv[1]; FILES=('plib.asm','fmt_%s.asm'%fmt,'plib_rnd.asm')
for it in range(80):
    try: bplug.build(fmt); break
    except Exception as e:
        m=re.match(r'line (\d+): JR range -?\d+: (.*)$',str(e))
        if not m: raise
        line=m.group(2)
        fixed=False
        for fn in FILES:
            t=open(fn).read()
            if line+'\n' in t:
                t=t.replace(line+'\n',line.replace('JR ','JP ',1)+'\n'); open(fn,'w').write(t); fixed=True; print('fixed',line.strip(),fn)
        assert fixed,line
