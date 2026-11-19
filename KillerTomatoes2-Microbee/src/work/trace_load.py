"""Trace the loader in the boot model: PC, bank and input pointer as it runs."""
from test_plus import *
class PlusBoot(BootBee):
 def __init__(self):
  super().__init__();self.ram=[bytearray(32768) for _ in range(32)];self.pcg=[bytearray(2048) for _ in range(16)]
  self.bank_writes=set();self.pcg_writes=set();self.disk=Path('outputs/KILLTPP.DS80').read_bytes()
 def read(self,a):
  return PlusBee.read(self,a) if self.bank&4 and not self.bank&16 else BootBee.read(self,a)
 def write(self,a,v):
  return PlusBee.write(self,a,v) if self.bank&4 and not self.bank&16 else BootBee.write(self,a,v)
b = PlusBoot(); m = b.m; queue = list(b'KILLTOM2\r'); con = []
for pc in [0xe406, 0xe409, 0xe40c, sym['hw_init'], sym['lz_fail']]: m.set_breakpoint(pc)
print({k: hex(sym[k]) for k in ['lz_load', 'lz_bank', 'lz_refill', 'load_bank', 'lz_in', 'asset_fcb']})
def ret():
    m.pc = b.read(m.sp) | (b.read((m.sp + 1) & 65535) << 8); m.sp = (m.sp + 2) & 65535
for i in range(6000):
    b.run(ticks=100000)
    if m.pc == 0xe406: m.a = 255 if queue else 0; ret()
    elif m.pc == 0xe409: m.a = queue.pop(0) if queue else 13; ret()
    elif m.pc == 0xe40c: con.append(chr(m.c & 127)); ret()
    elif m.pc in (sym['hw_init'], sym['lz_fail']): print('STOP at', hex(m.pc)); break
    if i % 100 == 0:
        print(i, 'pc', hex(m.pc), 'port', hex(b.bank), 'bank', b.read(sym['load_bank']),
              'in', hex(b.read(sym['lz_in']) | b.read(sym['lz_in'] + 1) << 8),
              'fcb', bytes(b.read(sym['asset_fcb'] + j) for j in range(1, 12)), 'fdc', len(b.fdc_reads), flush=True)
print(repr(''.join(con)[-300:]))
