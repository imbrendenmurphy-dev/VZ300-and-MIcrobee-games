#!/bin/sh
# Debug build where a bot plays, starting at stage N (0-13). Writes build/auto.vz
# Run it in the test emulator, e.g.:  ../tools/vzemu build/auto.vz -big -f 15000 -s 1000,5000 -o shot
cd "$(dirname "$0")"
mkdir -p build
sjasmplus --nologo -DAUTOPLAY -DSTARTST=${1:-0} --sym=build/auto.sym main.asm >/dev/null
python3 mkvz.py build/game.bin build/auto.vz AUTO 8000
