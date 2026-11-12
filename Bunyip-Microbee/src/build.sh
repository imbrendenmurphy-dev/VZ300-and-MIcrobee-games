#!/bin/sh
# Build script for the BEECAST raycaster test (VIBED BY BPM 2026)
set -e
cd "$(dirname "$0")"
mkdir -p build
gcc -O2 -o build/beemu tools/beemu.c
python3 tools/gen.py build
python3 tools/zasm.py src/vidmap.asm -o build/vidmap.bin
python3 tools/zasm.py src/ray.asm -o build/RAY.COM -l build/ray.lst -s build/ray.sym
python3 tools/build_disk.py
