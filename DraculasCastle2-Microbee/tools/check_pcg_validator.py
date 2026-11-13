"""Negative controls for the mandatory hardware validator."""
from pathlib import Path
import subprocess,sys
from PIL import Image
import pcg_validate as v

out=Path(__file__).resolve().parent.parent/'build/validator-tests';out.mkdir(exist_ok=True)
im=Image.new('RGB',(16,8));im.putpixel((0,0),tuple(v.PALETTE[15]));assert v.inspect(im)['invalid_cells']==0
im.putpixel((1,0),tuple(v.PALETTE[9]));r=v.inspect(im)
assert r['invalid_cells']==1 and r['offending_cells'][0]['x']==0 and r['offending_cells'][0]['count']==3
im.save(out/'three-colours.png')
p=subprocess.run([sys.executable,str(Path(v.__file__)),str(out/'three-colours.png'),'--out',str(out/'diagnostic'),'--grid'],capture_output=True,text=True)
assert p.returncode==1 and (out/'diagnostic.png').exists()
im=Image.new('RGB',(8,8),(1,2,3));assert v.inspect(im)['invalid_cells']==1
raw=bytearray(1280*17)
assert v.inspect(v.unpack_raw(raw))['invalid_cells']==0
raw[8]=1
try:v.unpack_raw(raw)
except ValueError:pass
else:raise AssertionError('Hidden scanline corruption accepted')
for codes,attrs in ((bytes([0])*1280,bytes(1280)),(bytes([128])*1280,bytes([16])*1280),(bytes([129])*1280,bytes(1280))):
    try:v.planes(bytes(16),codes,attrs,bytes(1280))
    except ValueError:pass
    else:raise AssertionError('Invalid PCG reference accepted')
try:v.group_frames(bytes(32769))
except ValueError:pass
else:raise AssertionError('Oversized RAM group accepted')
print('PASS validator: three-colour cell, off-palette RGB, ROM reference, attribute flags, bad index, hidden rows, RAM overflow, failing CLI and diagnostic')
atlas=(out.parent/'world/world0-colour.raw').read_bytes()
v.world_packet(atlas)
for offset in (64,2,0):
    broken=bytearray(atlas);broken[offset:offset+2]=b'\0\0'
    try:v.world_packet(broken)
    except ValueError:pass
    else:raise AssertionError('Invalid world header/pointer accepted')
print('PASS world atlas allocation and invalid component-pointer controls')
