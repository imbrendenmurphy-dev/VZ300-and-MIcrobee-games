"""Make an 80-track double-sided Microbee CP/M disk, retaining boot tracks."""
from pathlib import Path
import sys,hashlib
ROOT=Path(__file__).resolve().parents[1]
def system_files(source):
 """Boot tracks + CCP.SYS from a resources folder, or from a CP/M DS80/DS8 boot disk."""
 source=Path(source)
 if source.is_dir():return (source/'boot_tracks.bin').read_bytes(),(source/'CCP.SYS').read_bytes()
 base=source.read_bytes();assert len(base)==819200
 directory=bytes(base[20480+_off(i)] for i in range(4096))
 e=next(directory[i:i+32] for i in range(0,4096,32) if directory[i+1:i+12]==b'CCP     SYS')
 ccp=b''.join(bytes(base[20480+_off(b*4096+i)] for i in range(4096)) for b in e[16:] if b)[:e[15]*128]
 return base[:20480],ccp
_reverse=[4,1,8,5,2,9,6,3,10,7];_forward=[_reverse.index(i+1) for i in range(10)]
def _off(pos):
 sector,byte=divmod(pos,512);track,s=divmod(sector,10)
 return track*5120+_forward[s]*512+byte
def build(base_path,output):
 boot,ccp=system_files(base_path);assert len(boot)==20480
 image=bytearray(b'\xe5'*819200);image[:20480]=boot
 reverse=[4,1,8,5,2,9,6,3,10,7];forward=[reverse.index(i+1) for i in range(10)]
 def offset(pos):
  sector,byte=divmod(pos,512);track,s=divmod(sector,10)
  return 20480+track*5120+forward[s]*512+byte
 def read(src,pos,n):return bytes(src[offset(pos+i)] for i in range(n))
 def write(pos,data):
  for i,v in enumerate(data):image[offset(pos+i)]=v
 write(0,b'\xe5'*4096)
 nextblock=1;entry=0;expected={}
 def add(name,data):
  nonlocal nextblock,entry
  n=(len(data)+4095)//4096;blocks=list(range(nextblock,nextblock+n));nextblock+=n
  assert nextblock*4096<=len(image)-20480
  write(blocks[0]*4096,data+b'\x1a'*((-len(data))%4096))
  for k in range(0,n,16):
   chunk=blocks[k:k+16];size=min(len(data)-k*4096,65536);records=(size+127)//128
   e=bytearray(32);stem,ext=name.split('.');e[1:9]=stem.ljust(8).encode();e[9:12]=ext.ljust(3).encode()
   extent=k//4+(records-1)//128;e[12]=extent&31;e[14]=extent>>5;e[15]=records-128*((records-1)//128)
   e[16:16+len(chunk)]=bytes(chunk);write(entry*32,e);entry+=1
  expected[name]=data
 assert len(ccp)==2432
 add('CCP.SYS',ccp)
 add('KILLTOM2.COM',(ROOT/'build/KILLTOM2.COM').read_bytes())
 packed=(ROOT/'assets/KILLTOM2.PAK').read_bytes()
 for i,start in enumerate(range(0,len(packed),16384)):add(f'KILLTOM2.P{i:02d}',packed[start:start+16384])
 add('READ.ME',b'KILLER TOMATOES 2 - PREMIUM PLUS\r\n1MB RAM, 32KB PCG, 320x250 PAL.\r\nType KILLTOM2 at the CP/M A> prompt.\r\nTitle: M colour/dithered monochrome; D difficulty; T trainer; L stage.\r\nSPACE starts. Q/A/O/P move; SPACE trap/whack; Z ketchup.\r\nRETURN pause; R returns to title from pause; S sound.\r\n\x1a')
 # Verify by decoding the directory, including multiple physical extents.
 directory=read(image,0,4096)
 for name,data in expected.items():
  stem,ext=name.split('.');key=(stem.ljust(8)+ext.ljust(3)).encode();chunks=[]
  for i in range(0,4096,32):
   e=directory[i:i+32]
   if e[0]!=0 or e[1:12]!=key:continue
   ex=e[12]+32*e[14];size=((ex&3)*128+e[15])*128
   chunks.append((ex,b''.join(read(image,b*4096,4096) for b in e[16:] if b)[:size]))
  restored=b''.join(c[1] for c in sorted(chunks))
  assert restored[:len(data)]==data,name
 assert image[:20480]==boot
 output=Path(output);output.parent.mkdir(parents=True,exist_ok=True);output.write_bytes(image)
 print('Verified boot tracks, directory extents and every file:',output)
 print('SHA256',hashlib.sha256(image).hexdigest())
if __name__=='__main__':build(sys.argv[1],sys.argv[2] if len(sys.argv)>2 else ROOT/'build/KILLTPP.DS80')
