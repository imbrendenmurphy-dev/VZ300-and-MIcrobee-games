#!/bin/sh
# run.sh frames "f1,f2,..." [keyscript] [extra vzemu args] -> $OUT/sheet.png
F=$1; S=$2; K=$3; shift 3
OUT=${OUT:-/tmp/claude-0/sw}
mkdir -p $OUT; rm -f $OUT/t_*.ppm
cd "$(dirname "$0")/.."
./tools/vzemu/vzemu build/STARWHRL.VZ -bennvenn -frames $F -shots $S -out $OUT/t ${K:+-keys $K} "$@"
OUT=$OUT python3 - <<'P'
import glob, os
from PIL import Image
o=os.environ['OUT']
fs=sorted(glob.glob(o+'/t_*.ppm'))
ims=[Image.open(f) for f in fs]
if ims:
    w,h=ims[0].size
    n=len(ims); cols=2 if n>1 else 1; rows=(n+1)//2
    W=Image.new('RGB',(w*cols,h*rows))
    for i,im in enumerate(ims): W.paste(im,((i%2)*w,(i//2)*h))
    W=W.resize((W.width*2,W.height*2),Image.NEAREST)
    W.save(o+'/sheet.png')
P
