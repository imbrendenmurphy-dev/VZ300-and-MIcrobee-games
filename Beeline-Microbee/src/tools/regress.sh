#!/bin/sh
# regress.sh outdir : deterministic render (autopilot, fixed 5 physics steps per frame)
# writes frames every 40 fields; compare two outdirs with tools/imgcmp.py
./build.sh >/dev/null 2>&1 || exit 1
AD=$(grep " autodrive$" build/race.sym | cut -d' ' -f1)
FX=$(grep " fixdt$" build/race.sym | cut -d' ' -f1)
python3 tools/run.py build/RACE.COM build/race.sym 1200 tests/accel.keys $1 --every 8 --first 40 --flips --poke 0x$AD,1 --poke 0x$FX,5 --vwait 4 | tail -1
