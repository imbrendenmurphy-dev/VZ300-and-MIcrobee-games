#!/bin/sh
# uB-TYPE build: data and art generators, the Z80 assembler, the disk
set -e
cd "$(dirname "$0")"
mkdir -p build
python3 tools/mkdata.py          # stage data, sprites, terrain, bosses -> build/
python3 tools/mkfront.py         # front-end art, text, music -> build/
(cd src && python3 ../tools/zasm.py main.asm --sym=../build/main.sym)
(cd src && python3 ../tools/zasm.py loader.asm)
python3 tools/build_disk.py      # -> build/UBTYPE.DS8
