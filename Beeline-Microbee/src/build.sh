#!/bin/sh
# Build script for the Microbee Premium Plus racing experiments (ViBED by BPM)
set -e
cd "$(dirname "$0")"
mkdir -p build
gcc -O2 -o build/beemu tools/beemu.c
python3 tools/mkgfx.py build
python3 tools/mktrack.py build
python3 tools/mktraffic.py build
python3 tools/mksound.py build
python3 tools/zasm.py src/vidmap.asm -o build/vidmap.bin
python3 tools/zasm.py src/race.asm -o build/BEELINE.COM -l build/beeline.lst -s build/beeline.sym --split 0x9000 build/BEELINE.DAT
python3 tools/zasm.py src/bench.asm -o build/BENCH.COM -s build/bench.sym
python3 tools/mkcube.py build && python3 tools/zasm.py src/cube.asm -o build/CUBE.COM -s build/cube.sym
python3 tools/build_disk.py
