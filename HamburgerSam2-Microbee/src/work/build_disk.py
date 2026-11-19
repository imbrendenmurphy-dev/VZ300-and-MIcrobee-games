from pathlib import Path
import math,hashlib,sys
out=Path('outputs');out.mkdir(exist_ok=True)
# Boot tracks + CCP.SYS come from resources/ (extracted once from a Microbee
# CP/M boot disk) or, given a path, straight from such a .DS8 image.
RES=Path('resources')
use_res=len(sys.argv)<2 and (RES/'boot_tracks.bin').exists() and (RES/'CCP.SYS').exists()
base=(RES/'boot_tracks.bin').read_bytes()+b'\xe5'*(819200-20480) if use_res else \
 Path(sys.argv[1] if len(sys.argv)>1 else r'C:/Users/Owner/OneDrive/Documents/Microbee/DRVB.DS8').read_bytes()
# Microbee DS80: 80 cylinders, 2 heads, 10x512; four reserved head-tracks,
# 4KiB allocation blocks, 128 directory entries, 3:1 sector interleave.
image=bytearray(b'\xe5'*819200);image[:20480]=base[:20480]
reverse=[4,1,8,5,2,9,6,3,10,7]
forward=[reverse.index(i+1) for i in range(10)]
def offset(sector):
 track,s=divmod(sector,10)
 return 20480+track*5120+forward[s]*512
def write_logical(pos,data):
 for i,b in enumerate(data):
  sector,k=divmod(pos+i,512);image[offset(sector)+k]=b
def read_logical(pos,n):
 return bytes(image[offset((pos+i)//512)+(pos+i)%512] for i in range(n))
write_logical(0,b'\xe5'*4096)
nextblock=1;entry=0
def add(name,data):
 global nextblock,entry
 n=(len(data)+4095)//4096;blocks=list(range(nextblock,nextblock+n));nextblock+=n
 write_logical(blocks[0]*4096,data+b'\x1a'*((-len(data))%4096))
 # DSM<256 gives sixteen 8-bit allocation pointers, EXM=3.
 for k in range(0,n,16):
  chunk=blocks[k:k+16];size=min(len(data)-k*4096,65536);records=(size+127)//128
  e=bytearray(32);stem,ext=name.split('.');e[1:9]=stem.ljust(8).encode();e[9:12]=ext.ljust(3).encode()
  extent=(k*4096)//16384+(records-1)//128;e[12]=extent&31;e[14]=extent>>5;e[15]=records-128*((records-1)//128)
  e[16:16+len(chunk)]=bytes(chunk);write_logical(entry*32,e);entry+=1
 assert read_logical(blocks[0]*4096,len(data))==data
 print(name,len(data),'blocks',blocks)
def read_base(pos,n):
 return bytes(base[offset((pos+i)//512)+(pos+i)%512] for i in range(n))
# Restore the original plain command processor, not the graphical Shell.
if use_res:
 ccp=(RES/'CCP.SYS').read_bytes()
else:
 directory=read_base(0,4096)
 ccp_entry=next(directory[i:i+32] for i in range(0,4096,32) if directory[i+1:i+12]==b'CCP     SYS')
 ccp=b''.join(read_base(block*4096,4096) for block in ccp_entry[16:] if block)
 ccp=ccp[:ccp_entry[15]*128]
 RES.mkdir(exist_ok=True);(RES/'boot_tracks.bin').write_bytes(base[:20480]);(RES/'CCP.SYS').write_bytes(ccp)
assert len(ccp)==2432
add('CCP.SYS',ccp)
add('HAMSAM2.COM',Path('work/port/build/HAMSAM2.COM').read_bytes())
add('HAMSAM2.DAT',Path('work/port/build/HAMSAM2.DAT').read_bytes())
add('READ.ME',b'HAMBURGER SAM II - THE BURGER RUSH\r\nMicrobee Premium Plus edition v1.0\r\n\r\nRequires a Premium Plus (1MB RAM, 32K PCG RAM).\r\nType HAMSAM2 at the A> prompt to play.\r\n\r\nM / comma : walk left / right\r\nQ / A     : climb up / down\r\nSPACE     : throw pepper (and start)\r\nP pause, X (while paused) quit, S sound\r\nV on the title: colour or dithered mono\r\nC on the title or menu: unlock Classic 1984\r\nName entry: Q/A letter, SPACE next,\r\n            RETURN when done\r\n\x1a')
(out/'HAMSAM2.DS80').write_bytes(image)
assert image[:20480]==base[:20480]
print('PASS boot tracks unchanged; DS80 file extraction matches COM byte for byte',hashlib.sha256(image).hexdigest())
