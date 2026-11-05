#!/bin/sh
# usage: ./build.sh          release build -> build/DRACULA2.VZ + build/sd/DC2*.DAT
#        ./build.sh --debug  test build (no random battles, strong hero) -> build/DRACDBG.VZ
# tools/egg.py needs orig/lines.pkl: run  python3 tools/detok.py DRACULA.VZ  on the original game first.
set -e
cd "$(dirname "$0")"
python3 tools/build.py "$@"
