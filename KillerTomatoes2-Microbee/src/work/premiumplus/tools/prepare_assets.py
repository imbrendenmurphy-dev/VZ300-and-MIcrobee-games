"""Compile native art into banked, pre-shifted PCG cell records."""
from arcade_art import *
from collections import Counter
import re,struct

def pack(data):
 out=bytearray();i=0
 while i<len(data):
  n=1
  while i+n<len(data) and data[i+n]==data[i] and n<129:n+=1
  if n>=3:out.extend((n-2,data[i]));i+=n;continue
  start=i;i+=n
  while i<len(data) and i-start<128:
   if i+2<len(data) and data[i]==data[i+1]==data[i+2]:break
   i+=1
  out.append(128+i-start-1);out.extend(data[start:i])
 out.append(0);return out

def lz_bank(data, depth=256):
 """One 32K bank -> tokens decoded by loader.inc: 0 end, 1..127 literals,
 128+len-4 dist16 match (len 4..131). Lazy greedy over 3-byte hash chains."""
 out=bytearray();lit=bytearray();chains={};n=len(data)
 def best(i):
  bl=bd=0;limit=min(131,n-i)
  if limit<4:return 0,0
  for j in reversed(chains.get(data[i:i+3],[])[-depth:]):
   l=0
   while l<limit and data[j+l]==data[i+l]:l+=1
   if l>bl:bl,bd=l,i-j
   if l==limit:break
  return bl,bd
 def flush():
  for k in range(0,len(lit),127):
   chunk=lit[k:k+127];out.append(len(chunk));out.extend(chunk)
  lit.clear()
 def add(i):chains.setdefault(data[i:i+3],[]).append(i)
 i=0
 while i<n:
  l,d=best(i)
  if l>=4 and i+1<n:
   add(i);l2,_=best(i+1)
   if l2>l+1:lit.append(data[i]);i+=1;continue
   chains[data[i:i+3]].pop()
  if l>=4:
   flush();out.extend((128+l-4,d&255,d>>8))
   for k in range(i,i+l):add(k)
   i+=l
  else:add(i);lit.append(data[i]);i+=1
 flush();out.append(0);return out

def unlz_bank(src,pos):
 out=bytearray()
 while True:
  t=src[pos];pos+=1
  if t==0:return bytes(out),pos
  if t<128:out.extend(src[pos:pos+t]);pos+=t
  else:
   l=t-124;d=src[pos]|src[pos+1]<<8;pos+=2
   for _ in range(l):out.append(out[-d])

source=ROOT/'assets'/'native_manifest.json'
if not source.exists():
 text=(ROOT/'src/native_art.inc').read_text()
 data={m[1]:[int(x) for x in re.findall(r'\d+',m[2])] for m in re.finditer(r'^(spr_\w+|tl_\w+):\n((?: db[^\n]*\n)+)',text,re.M)}
 source.write_text(json.dumps(data))
 (ROOT/'assets/font_source.inc').write_text(text[:text.index('spr_PR1:')]+text[text.index('title_tomato:'):])
data=json.loads(source.read_text())
blocks=[bytearray()];physical=list(range(4,32));manifest={};out=[]
def allocate(name,payload):
 assert len(payload)<=32768,(name,len(payload))
 if len(blocks[-1])+len(payload)>32768:blocks.append(bytearray())
 i=len(blocks)-1;assert i<len(physical),'1MB asset RAM exhausted'
 off=len(blocks[-1]);blocks[-1].extend(payload)
 bank=physical[i];port=((bank&3)^2)|4|((bank&28)<<3)
 manifest[name]={'bank':bank,'port':port,'offset':off,'length':len(payload)}
 return port,off

def asset(name,old):
 w,h=old[0]*8,old[1];n=name.split('_',1)[1];frame=int(n[-1]) if n[-1:].isdigit() else 0
 if name.startswith('spr_'):
  if n[:2] in ('PR','PL','PU','PD') and not n.startswith('PDIE'):return player(n[1],frame)
  if n=='PWIN':return player('R',frame)
  for kind in ['MAMA','BARON','GREAT','CH','RO','BF','UN','GO','HOP','ROT','BALL']:
   if n.startswith(kind):return tomato(kind,frame,w,h)
 if n=='W_BRICK':return tile('brick',frame)
 if n=='W_CANS':return tile('machine',frame)
 if n=='W_LAB':return tile('lab',frame)
 if n.startswith('T_TRAP'):return tile('trap'+(n[-1] if n[-1].isdigit() else '3'),frame)
 # Preserve native hand-drawn icons as a base; never read VZ pixels.
 im=canvas(w,h);d=ImageDraw.Draw(im);col=old[2]
 for y in range(h):
  for x in range(w):
   value=old[3+y*(w//8)+x//8]&(128>>(x%8))
   if value or name.startswith('tl_'):d.point((x,y),fill=ink(col&15 if value else col>>4))
 return im

for name,old in data.items():
 im=asset(name,old);wc=im.width//8+1;hc=im.height//10+1;stride=wc*hc*21;payload=bytearray()
 for mono in [False,True]:
  for dx in [0,4]:
   for dy in range(0,10,2):
    shifted=canvas(wc*8,hc*10);shifted.alpha_composite(im,(dx,dy))
    payload.extend(b''.join(compile_cells(shifted,mono)[2]))
 fast_offset=len(payload)
 if name.startswith('tl_'):
  for mono in [False,True]:
   for r in compile_cells(im,mono)[2]:payload.extend(r[10:20]+bytes(4)+r[20:21]+bytes(1))
 port,off=allocate(name,payload)
 out.extend([name+':',f' db 255,{port}',f' dw {off},{stride}',f' db {wc},{hc}'])
 if name.startswith('tl_'):out.append(f' dw {off+fast_offset}')
 print(name,len(payload),flush=True)

for mono in [False,True]:
 native=bytearray()
 for r in compile_cells(title(),mono)[2]:native.extend(r[10:20]+bytes(4)+r[20:21]+bytes(1))
 port,off=allocate('title_'+str(int(mono)),native)
 out.extend(['plus_title_'+str(int(mono))+':',f' db {port}',f' dw {off}'])

raw=b''.join(bytes(b)+bytes(32768-len(b)) for b in blocks)
out.append(f'ASSET_BANKS equ {len(blocks)}')
hud=canvas(320,10);draw=ImageDraw.Draw(hud);draw.fontmode='1';box(draw,(0,0,319,9),0)
hf=ImageFont.truetype('C:/Windows/Fonts/consolab.ttf',8)
for x,label in [(32,'SCORE'),(112,'SAUCE'),(168,'K'),(192,'LEFT'),(224,'LIFE'),(256,'STAGE')]:draw.text((x,-1),label,font=hf,fill=ink(14))
line(draw,(0,9,319,9),14)
out.append('plus_hud_data:')
for r in compile_cells(hud)[2]:out.append(' db '+','.join(map(str,r[10:21])))
packed=b''.join(lz_bank(raw[k:k+32768]) for k in range(0,len(raw),32768))
pos=0
for k in range(0,len(raw),32768):
 bank,pos=unlz_bank(packed,pos);assert bank==raw[k:k+32768],('LZ round trip',k//32768)
assert pos==len(packed)
(ROOT/'assets/KILLTOM2.PAK').write_bytes(packed)
(ROOT/'assets/banks.bin').write_bytes(raw)
(ROOT/'assets/banks.json').write_text(json.dumps(manifest,indent=2))
(ROOT/'src/native_art.inc').write_text((ROOT/'assets/font_source.inc').read_text()+'\n'+'\n'.join(out)+'\n')
print('RAM:',len(raw),'packed:',len(packed),'physical banks:',physical[:len(blocks)])

