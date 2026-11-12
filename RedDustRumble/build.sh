#!/bin/sh
# RED DUST RUMBLE build: python3 only.  -> build/RUMBLE.VZ
set -e
cd "$(dirname "$0")"
mkdir -p build src/gen
python3 tools/art.py src/gen > build/art.txt
python3 tools/mktables.py src/gen
python3 tools/stage.py src/gen
cd src
python3 ../tools/z80asm.py main.asm ../build/RUMBLE.bin ../build/RUMBLE.sym > ../build/asm.txt
cd ..
python3 tools/mkvz.py build/RUMBLE.bin build/RUMBLE.VZ 8000 RUMBLE
cat build/art.txt
