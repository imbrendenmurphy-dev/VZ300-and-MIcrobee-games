#!/bin/sh
# INTERNATIONAL FISTICUFFS! build: python3 only (Pillow for the art).
#   build/FISTICUF.VZ and build/sd/FISTCUF0-9.DAT  (copy all eleven to the SD card)
set -e
cd "$(dirname "$0")"
mkdir -p build/sd src/gen
python3 tools/art.py src/gen > build/art.txt
python3 tools/mktables.py src/gen
python3 tools/pack.py src/gen build/sd > build/pack.txt
cd src
python3 ../tools/z80asm.py main.asm ../build/FISTICUF.bin ../build/FISTICUF.sym > ../build/asm.txt
cd ..
python3 tools/mkvz.py build/FISTICUF.bin build/FISTICUF.VZ 8000 FISTICUF
cat build/pack.txt
