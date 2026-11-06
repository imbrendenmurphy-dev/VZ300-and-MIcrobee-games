#!/bin/sh
# KAMIKAZE INVADERS 2 build: needs python3 + Pillow, and sjasmplus on your PATH
# (or set SJASMPLUS=/path/to/sjasmplus)
set -e
cd "$(dirname "$0")"
SJ=${SJASMPLUS:-sjasmplus}
mkdir -p ../build
python3 gen.py
$SJ --nologo --msg=war --sym=../build/kami2.sym main.asm
python3 mkvz.py kami2.bin ../build/KAMI2.VZ "KAMIKAZE 2" 8000
