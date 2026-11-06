#!/bin/sh
# shot.sh frames "f1,f2,.." [keys] [extra vzemu args] -> /tmp/claude-0/s/d_*.png sheet
F=$1; S=$2; K=$3; shift 3
cd "$(dirname "$0")/.."
rm -f /tmp/claude-0/s/d_*.ppm
./tools/vzemu/vzemu build/DUEL2.VZ -frames $F -shots $S -out /tmp/claude-0/s/d ${K:+-keys $K} "$@"
python3 - <<'P'
import glob
from PIL import Image
fs=sorted(glob.glob('/tmp/claude-0/s/d_*.ppm'))
ims=[Image.open(f).resize((640,480),0) for f in fs]
if ims:
    n=len(ims); cols=2 if n>1 else 1; rows=(n+1)//2
    W=Image.new('RGB',(640*cols,480*rows))
    for i,im in enumerate(ims): W.paste(im,((i%2)*640,(i//2)*480))
    W.save('/tmp/claude-0/s/sheet.png')
P
