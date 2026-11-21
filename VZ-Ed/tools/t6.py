import sys; sys.path.insert(0,'.')
from harness import *
import shot
S= os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),'testout','')
dos=open('VZDOS.VZ','rb').read(); ed=open('../out/VZED.VZ','rb').read()
sym={l.split()[1]:int(l.split()[0],16) for l in open('../out/vzed.sym')}
doc=b"Dear VZ friends,\r\n\r\nThis letter was written on a Dick Smith\r\nVZ300 with VZ-ED 0.1 and saved\r\nstraight to the SD card.\r\n\r\nThe quick brown fox jumps over the\r\nlazy dog: 0123456789 !?@#$%&*()\r\n<tags> [brackets] {braces} a_b ~x\r\n\r\nCheers,\r\nBPM\r\n"
c=Card(spc=8); c.addfile(2,'VZDOS.VZ',dos); c.addfile(2,'SHELL.VZ',ed); c.addfile(2,'LETTER.TXT',doc)
d=c.mkdir(2,'GAMES'); c.addfile(2,'NOTES.TXT',b'x'*1234); c.addfile(2,'README.TXT',b'r'*20); c.addfile(2,'VZED.OVL',open('../out/VZED.OVL','rb').read())
c.finish()
m=VZ(dos[24:],c,maxlba=max(c.sec)+5000)
codeend=sym['code_end']
def guard(a,v):
    pc=m.z.pc
    if 0xA000<=pc<codeend:
        if 0xFA00<=a<=0xFFFF and a not in (0xFB06,0xFB07,0xFB08,0xFB09,0xFB80,0xFB81) and not (0xFF00<=a): return True
        if 0x7800<=a<0x8000 and not (0x7600<=a<0x7700): return True
    return False
m.guard=guard
m.run(0x4004,frames=120)
m.type_keys([('CTRL','O'),('WAIT',20)]); m.run_script(extra=5); shot.save(m,S+'s_list_text.png')
m.type_keys(['SPACE','RET',('WAIT',30),('CTRL','SPACE'),('CTRL','SPACE'),('CTRL',','),('CTRL',',')]); m.run_script(extra=3)
m.z.mem[sym['blinkon']]=1
shot.save(m,S+'s_text0.png')
m.type_keys([('CTRL','D'),('WAIT',5),'SPACE',('CTRL',':')]); m.run_script(extra=3); shot.save(m,S+'s_text1.png')
m.type_keys([('CTRL','D'),('WAIT',5),'SPACE',('CTRL',':')]); m.run_script(extra=3); shot.save(m,S+'s_gfx.png')
m.type_keys([('CTRL','L'),('WAIT',5)]); m.run_script(extra=3); shot.save(m,S+'s_gfx_ovr.png')
m.type_keys([('CTRL','L'),('CTRL','H'),('WAIT',5)]); m.run_script(extra=3); shot.save(m,S+'s_gfx_help1.png')
m.type_keys(['SPACE',('WAIT',5)]); m.run_script(extra=3); shot.save(m,S+'s_gfx_help2.png')
m.type_keys([('CTRL','Q'),('WAIT',5),('CTRL','O'),('WAIT',20)]); m.run_script(extra=3); shot.save(m,S+'s_gfx_list.png')
m.type_keys([('CTRL','Q'),('WAIT',5),('CTRL','A'),('WAIT',5)]+text_for('copy')); m.run_script(extra=3); shot.save(m,S+'s_gfx_saveas.png')
m.type_keys([('CTRL','D'),('WAIT',5),('CTRL','H'),('WAIT',5)]); m.run_script(extra=3)
print('guard hits', m.writes_low[:10], len(m.writes_low)); print(m.text())
