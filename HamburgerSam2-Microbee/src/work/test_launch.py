from test_boot import *
b=BootBee();m=b.m
for pc in [0xe406,0xe409,0xe40c,0x100]:m.set_breakpoint(pc)
queue=list(b'HAMSAM2\r');console=[]
def ret():
 m.pc=b.read(m.sp)|(b.read((m.sp+1)&65535)<<8);m.sp=(m.sp+2)&65535
for i in range(2000):
 b.run(ticks=100000)
 if m.pc==0xe406:
  m.a=255 if queue else 0;ret()
 elif m.pc==0xe409:
  assert queue,repr(''.join(console))
  m.a=queue.pop(0);ret()
 elif m.pc==0xe40c:
  console.append(chr(m.c&127));ret()
 elif m.pc==0x100:
  expected=Path('work/port/build/HAMSAM2.COM').read_bytes()
  assert bytes(b.read(a) for a in range(0x100,0x100+len(expected)))==expected
  text=''.join(console)
  assert 'A>' in text,text
  print('PASS ROM boot -> CP/M A> prompt -> HAMSAM2 -> exact COM bytes loaded')
  print(repr(text));print('Disk read commands:',len(b.fdc_reads))
  Path('work/boot-launch.txt').write_text(text+'\nVerified COM bytes and entry point 0100h.\n')
  break
else:raise AssertionError((hex(m.pc),repr(''.join(console))))
