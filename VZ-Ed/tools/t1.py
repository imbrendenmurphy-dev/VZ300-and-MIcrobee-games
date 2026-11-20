import sys; sys.path.insert(0,'.')
from harness import *
dos=open('VZDOS.VZ','rb').read()[24:]
ed=open('../out/VZED.VZ','rb').read()
readme=b'VZ-ED test file\r\nSecond line with Mixed Case\r\n\r\nThe quick brown fox jumps over the lazy dog, again and again and again.\r\nLast line\r\n'
c=Card(spc=8)
c.addfile(2,'SHELL.VZ',ed)
c.addfile(2,'README.TXT',readme)
c.addfile(2,'UNIX.TXT',b'one\ntwo\nthree\n')
d=c.mkdir(2,'DOCS')
c.addfile(d,'NOTES.TXT',b'notes in a folder\r\n')
c.finish()
m=VZ(dos,c,maxlba=max(c.sec)+5000)
r=m.run(0x4004,frames=150)
print(r, m.con[-200:])
print(m.text())
print('pc %04X latch %02X'%(m.z.pc,m.latch))
print(bytes(m.z.mem[0x8000:0x8020]))
print(bytes(m.z.mem[0x7000:0x7020]).hex())
