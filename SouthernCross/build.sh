#!/bin/sh
# usage: ./build.sh [cheat [stage]]
#   -> build/SCROSS.VZ, build/SCROSS00.DAT (front end), build/SCROSS01-06.DAT (stages)
#   needs python3 (+Pillow for previews); emulator: gcc -O2 -o emu/vzemu emu/vzemu.c
set -e
cd "$(dirname "$0")"
mkdir -p build
# ./build.sh cheat [N]: invincible, starting at stage N (test builds only)
if [ "$1" = "cheat" ]; then printf "CHEAT equ 1\nSTART_STAGE equ %s\n" "${2:-1}" > src/build_opts.asm
else printf "CHEAT equ 0\nSTART_STAGE equ 1\n" > src/build_opts.asm; fi
python3 tools/mkassets.py src/gen > /dev/null
cd src
python3 ../tools/z80asm.py main.asm ../build/SCROSS.bin ../build/SCROSS.sym
cd ..
python3 tools/mkvz.py build/SCROSS.bin build/SCROSS.VZ 8000 SCROSS
