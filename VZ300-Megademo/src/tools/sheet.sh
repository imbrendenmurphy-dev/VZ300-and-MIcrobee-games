#!/bin/bash
# sheet.sh video.mp4 t1 t2 ... -> /tmp/claude-0/sheet.png
V=$1; shift
cd /tmp/claude-0 && rm -f fr_*.png
for t in "$@"; do ffmpeg -loglevel error -ss $t -i $V -frames:v 1 -vf scale=320:240 fr_$t.png; done
python3 -c "
from PIL import Image,ImageDraw
import glob
fs=sorted(glob.glob('fr_*.png'),key=lambda x: float(x[3:-4]))
ims=[Image.open(f) for f in fs]
W,H=ims[0].size
n=len(ims); cols=4; rows=(n+3)//4
sheet=Image.new('RGB',(W*cols,H*rows))
for i,im in enumerate(ims):
  sheet.paste(im,((i%cols)*W,(i//cols)*H)); ImageDraw.Draw(sheet).text(((i%cols)*W+4,(i//cols)*H+4),fs[i],fill=(255,255,255))
sheet.save('sheet.png')"
