#!/bin/sh
# Ghost Hunter 2 build: needs python3 + Pillow, sjasmplus
set -e
cd "$(dirname "$0")"
SJ=${SJASMPLUS:-sjasmplus}
[ -x ../tools/sjasmplus/sjasmplus ] && SJ=../tools/sjasmplus/sjasmplus
python3 gen.py
$SJ --nologo --sym=../build/gh3.sym main.asm
mkdir -p ../build
python3 mkvz.py gh3.bin ../build/GHOST3.VZ "GHOST HUNTER 3D" 8000
