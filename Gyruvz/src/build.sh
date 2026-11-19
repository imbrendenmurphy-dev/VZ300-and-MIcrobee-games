#!/bin/sh
# GYRUVZ build: needs python3 (with Pillow) and sjasmplus on your PATH
# (or SJASMPLUS=/path/to/sjasmplus).
set -e
cd "$(dirname "$0")"
SJ=${SJASMPLUS:-sjasmplus}
mkdir -p ../build pics
python3 gfx.py gfx.inc
python3 music.py music.inc
python3 music3.py music3.inc
python3 tables.py tables.inc
python3 pics.py pics
# pass 1: assemble with an empty front-end payload, to get bank3.bin
printf '\377' > payload.lz
$SJ --nologo --msg=war main.asm > /dev/null
# pack the bank-3 front end into the payload, then the real build
python3 -c "import lz; d=open('bank3.bin','rb').read(); p=lz.pack(d); open('payload.lz','wb').write(p); print('front end: %d bytes, packed %d' % (len(d), len(p)))"
$SJ --nologo --msg=war --sym=../build/gyruvz.sym main.asm
python3 mkvz.py gyruvz.bin ../build/GYRUVZ.VZ "GYRUVZ" 8000
