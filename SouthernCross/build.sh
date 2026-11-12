#!/bin/sh
# usage: ./build.sh [cheat]
#   -> build/SCROSS.VZ, build/SCROSS00.DAT (front end), build/SCROSS01.DAT (stage 1)
#   needs python3 (+Pillow for previews); emulator: gcc -O2 -o emu/vzemu emu/vzemu.c
set -e
cd "$(dirname "$0")"
mkdir -p build
if [ "$1" = "cheat" ]; then echo "CHEAT equ 1" > src/build_opts.asm; else echo "CHEAT equ 0" > src/build_opts.asm; fi
python3 tools/mkassets.py src/gen > /dev/null
cd src
python3 ../tools/z80asm.py main.asm ../build/SCROSS.bin ../build/SCROSS.sym
cd ..
python3 tools/mkvz.py build/SCROSS.bin build/SCROSS.VZ 8000 SCROSS
