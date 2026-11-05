#!/bin/sh
# Build HOPPY2.VZ.  Needs python3 and sjasmplus (set SJASMPLUS if it isn't on your PATH).
set -e
cd "$(dirname "$0")"
SJ=${SJASMPLUS:-sjasmplus}
mkdir -p ../build
python3 tools/gen.py >/dev/null
python3 tools/music.py >/dev/null
$SJ --nologo --msg=war --sym=../build/hoppy2.sym main.asm $DEFS
python3 tools/mkvz.py ../build/hoppy2.bin ../release/HOPPY2.VZ HOPPY2 0x8000
