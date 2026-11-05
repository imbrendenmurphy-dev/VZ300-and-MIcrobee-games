import sys; sys.path.insert(0,'tools'); from dis import dis
d=open('orig/TENNIS.VZ','rb').read()[24:]; base=0x7AE9
m=bytearray(65536); m[base:base+len(d)]=d
# recursive trace
import re
seen={}; todo=[base]
while todo:
    pc=todo.pop()
    while base<=pc<base+len(d) and pc not in seen:
        try: n,s=dis(m,pc,0)
        except Exception as e: break
        seen[pc]=(n,s)
        mm=re.search(r'(JP|CALL|JR|DJNZ)[^\n]*?([0-9A-F]{4})$',s)
        if mm:
            t=int(mm.group(2),16); todo.append(t)
        if s.startswith(('JP ','JR ')) and ',' not in s or s=='RET' or s.startswith('JP (') or s in('RETI','RETN'): break
        pc+=n
out=[]
pc=base
while pc<base+len(d):
    if pc in seen:
        n,s=seen[pc]; out.append('%04X  %-12s %s'%(pc,' '.join('%02X'%m[pc+i] for i in range(n)),s)); pc+=n
    else:
        st=pc
        while pc<base+len(d) and pc not in seen and pc-st<16: pc+=1
        bs=m[st:pc]; out.append('%04X  DB %s  |%s|'%(st,' '.join('%02X'%x for x in bs),''.join(chr(x) if 32<=x<127 else '.' for x in bs)))
open('build/orig.dis','w').write('\n'.join(out))
print(len(seen))
