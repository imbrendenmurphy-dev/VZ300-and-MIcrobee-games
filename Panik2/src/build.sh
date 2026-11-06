#!/bin/sh
# PANIK 2 build: needs python3 + Pillow, and sjasmplus on your PATH
# (or set SJASMPLUS=/path/to/sjasmplus)
set -e
cd "$(dirname "$0")"
SJ=${SJASMPLUS:-sjasmplus}
mkdir -p ../build
python3 gen.py
$SJ --nologo --msg=war --sym=../build/panik2.sym main.asm
python3 mkvz.py panik2.bin ../build/PANIK2.VZ "PANIK 2" 8000
