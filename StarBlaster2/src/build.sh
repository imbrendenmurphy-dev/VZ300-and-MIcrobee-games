#!/bin/sh
# STAR BLASTER II build: needs python3 + Pillow, and sjasmplus on your PATH
# (or set SJASMPLUS=/path/to/sjasmplus)
set -e
cd "$(dirname "$0")"
SJ=${SJASMPLUS:-sjasmplus}
mkdir -p ../build
python3 gen.py
$SJ --nologo --msg=war --sym=../build/sb2.sym main.asm
python3 mkvz.py sb2.bin ../build/STARBLS2.VZ "STAR BLASTER 2" 8000
