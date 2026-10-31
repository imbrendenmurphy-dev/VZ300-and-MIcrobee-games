#!/bin/sh
# Ghost Hunter 2 build: needs python3 + Pillow, sjasmplus
set -e
cd "$(dirname "$0")"
SJ=${SJASMPLUS:-sjasmplus}
[ -x ../tools/sjasmplus/sjasmplus ] && SJ=../tools/sjasmplus/sjasmplus
python3 gen.py
$SJ --nologo --sym=../build/gh2.sym main.asm
mkdir -p ../build
python3 mkvz.py gh2.bin ../build/GHOST2.VZ "GHOST HUNTER 2" 8000
