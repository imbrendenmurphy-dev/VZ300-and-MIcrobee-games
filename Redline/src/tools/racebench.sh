#!/bin/sh
# run the attract demo (autopilot) and profile racing frames
cd "$(dirname "$0")/.."
T=$(grep "^tmark:" build/racer.sym | sed 's/.*0x0000//')
cat > out/rb.scr <<EOS
mapper 1
sd release
vz release/REDLINE.VZ
tmark $T out/tm.txt
frames ${1:-1500}
prof 1
frames ${2:-600}
profsave out/prof.txt
screen out/b1.ppm
EOS
timeout 300 emu/vzemu out/rb.scr 2>&1 | grep -v "^loaded\|DOS open"
W=${1:-1500}
N=$(awk -v w=$W '$1>=w' out/tm.txt | wc -l)
echo "frames $N; fields/frame:"; awk -v w=$W '$1>=w {print $3}' out/tm.txt | sort | uniq -c
python3 tools/prof.py out/prof.txt build/racer.sym $N | head -${3:-30}
python3 -c "
from PIL import Image
Image.open('out/b1.ppm').resize((512,384),Image.NEAREST).save('out/b1.png')"
