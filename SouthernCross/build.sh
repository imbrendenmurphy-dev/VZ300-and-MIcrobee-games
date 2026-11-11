#!/bin/sh
# usage: ./build.sh   -> build/SCTEST.VZ  (needs python3; emulator: gcc -O2 -o emu/vzemu emu/vzemu.c)
set -e
cd "$(dirname "$0")"
mkdir -p build
python3 tools/mkassets.py src/gen > /dev/null
cd src
python3 ../tools/z80asm.py main.asm ../build/SCTEST.bin ../build/SCTEST.sym
cd ..
python3 tools/mkvz.py build/SCTEST.bin build/SCTEST.VZ 8000 SCTEST
