#!/bin/sh
# usage: ./build.sh            release build -> build/GRAVGARG.VZ
#        ./build.sh dbg START ARMOUR OWNED CHEAT   -> build/DBG.VZ
set -e
cd "$(dirname "$0")"
python3 tools/mkassets.py src/gen > /dev/null
if [ "$1" = "dbg" ]; then
  printf "DBG_START equ %s\nDBG_ARMOUR equ %s\nDBG_OWNED equ %s\nDBG_CHEAT equ %s\n" "$2" "$3" "$4" "$5" > src/build_opts.asm
  OUT=DBG
else
  printf "DBG_START equ 16\nDBG_ARMOUR equ 1\nDBG_OWNED equ 1\nDBG_CHEAT equ 0\n" > src/build_opts.asm
  OUT=GRAVGARG
fi
python3 tools/z80asm.py src/main.asm build/$OUT.bin build/$OUT.sym > /dev/null
python3 tools/mkvz.py build/$OUT.bin build/$OUT.VZ 8000 GRAVESNGARGOYLES
# SD card set: the .VZ plus its pack files
mkdir -p build/sd
cp build/$OUT.VZ build/GNGFRONT.DAT build/GNGSTAG1.DAT build/sd/
ls -l build/sd | awk 'NR>1{printf "  %-14s %6d\n", $9, $5}'
