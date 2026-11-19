from test_plus import *
class PlusBoot(BootBee):
 def __init__(self):
  super().__init__();self.ram=[bytearray(32768) for _ in range(32)];self.pcg=[bytearray(2048) for _ in range(16)]
  self.bank_writes=set();self.pcg_writes=set();self.disk=Path('outputs/KILLTPP.DS80').read_bytes()
 def read(self,a):
  return PlusBee.read(self,a) if self.bank&4 and not self.bank&16 else BootBee.read(self,a)
 def write(self,a,v):
  return PlusBee.write(self,a,v) if self.bank&4 and not self.bank&16 else BootBee.write(self,a,v)
b=PlusBoot();m=b.m;queue=list(b'KILLTOM2\r');console=[]
for pc in [0xe406,0xe409,0xe40c,0x100,sym['hw_init'],sym['lz_fail']]:m.set_breakpoint(pc)
launched=False
def ret():
 m.pc=b.read(m.sp)|(b.read((m.sp+1)&65535)<<8);m.sp=(m.sp+2)&65535
for i in range(50000):
 b.run(ticks=100000)
 if m.pc==0xe406:m.a=255 if queue else 0;ret()
 elif m.pc==0xe409:
  assert queue,repr(''.join(console));m.a=queue.pop(0);ret()
 elif m.pc==0xe40c:console.append(chr(m.c&127));ret()
 elif m.pc==sym['lz_fail']:
  Path('work/plus-failed-memory.bin').write_bytes(bytes(b.read(a) for a in range(65536)))
  print('LOAD FAIL status',m.a,'FCB',list(b.read(sym['asset_fcb']+j) for j in range(36)),'FDC reads',len(b.fdc_reads),b.fdc_reads[-5:],flush=True)
  raise AssertionError('load_fail')
 elif m.pc==0x100:
  expected=(ROOT/'build/KILLTOM2.COM').read_bytes()
  assert bytes(b.read(a) for a in range(256,256+len(expected)))==expected
  assert 'A>' in ''.join(console)
  launched=True;m.clear_breakpoint(256)
  print('PASS boot ROM -> CP/M A> -> exact Premium Plus COM',flush=True)
 elif m.pc==sym['hw_init']:
  print('hw_init breakpoint bank',hex(b.bank),'load_bank',b.read(sym['load_bank']),'console',repr(''.join(console)),flush=True)
  assert launched
  raw=(ROOT/'assets/banks.bin').read_bytes();banks=list(range(4,32))
  Path('work/plus-boot-ram.bin').write_bytes(b''.join(b.ram))
  for bank in range(len(raw)//32768):
   wanted=raw[bank*32768:(bank+1)*32768]
   differences=[i for i in range(32768) if b.ram[banks[bank]][i]!=wanted[i]]
   if differences:print('BANK MISMATCH',banks[bank],len(differences),differences[:20],differences[-10:],flush=True)
  for bank in range(len(raw)//32768):assert b.ram[banks[bank]]==raw[bank*32768:(bank+1)*32768],('disk asset load',banks[bank])
  print('PASS actual CP/M sequential read and decompression of every graphics bank',flush=True)
  Path('work/plus-boot-log.txt').write_text(''.join(console)+'\nVerified all banked graphics from disk. FDC reads: '+str(len(b.fdc_reads)))
  break
else:raise AssertionError((hex(m.pc),''.join(console)))


