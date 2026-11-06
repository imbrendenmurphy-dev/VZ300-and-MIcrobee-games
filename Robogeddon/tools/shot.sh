#!/bin/sh
# shot.sh frames "f1,f2,.." [keyscript] [extra vzemu args] -> $OUT/sheet.png (2 columns)
F=$1; S=$2; K=$3; shift 3
OUT=${OUT:-/tmp/claude-0/s}
mkdir -p $OUT
cd "$(dirname "$0")/.."
rm -f $OUT/d_*.ppm
./tools/vzemu/vzemu build/ROBOGEDN.VZ -frames $F -shots $S -out $OUT/d ${K:+-keys $K} "$@"
OUT=$OUT python3 - <<'P'
import glob, os
from PIL import Image
o=os.environ['OUT']
fs=sorted(glob.glob(o+'/d_*.ppm'))
ims=[Image.open(f) for f in fs]
if ims:
    w,h=ims[0].size
    n=len(ims); cols=2 if n>1 else 1; rows=(n+1)//2
    W=Image.new('RGB',(w*cols,h*rows))
    for i,im in enumerate(ims): W.paste(im,((i%2)*w,(i//2)*h))
    W.save(o+'/sheet.png')
P
