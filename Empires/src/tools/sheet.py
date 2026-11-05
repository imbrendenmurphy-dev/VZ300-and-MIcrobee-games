import json,sys
from PIL import Image
d=json.load(open('build/art.json')); PAL=[tuple(c) for c in d['pal']]
ch=d['chars']; N=len(ch)
cols=32; S=3
rowsn=(N+cols-1)//cols
im=Image.new('RGB',(cols*8*S*2+40,rowsn*11*S*2+10),(40,40,40))
px=im.load()
for i,c in enumerate(ch):
  for mode in range(2):
    gx=(i%cols)*8*S + mode*(cols*8*S+20); gy=(i//cols)*11*S*2
    rows=c['rows'] if mode==0 else c['mono']
    fg=PAL[c['fg']] if mode==0 else (255,176,0); bg=PAL[c['bg']] if mode==0 else (20,10,0)
    for y in range(11):
      for x in range(8):
        col=fg if rows[y]&(0x80>>x) else bg
        for a in range(S):
          for b in range(int(S*1.82)):
            px[gx+x*S+a, gy+y*int(S*1.82)+b]=col
im.save('build/sheet.png'); print(im.size)
