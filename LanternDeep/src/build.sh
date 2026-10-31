#!/bin/sh
# THE LANTERN DEEP - full rebuild
# Needs: Python 3 with numpy + Pillow, sjasmplus, ffmpeg, flite (for the
# speech; the last build's AUDIO.BNK is reused if flite is missing).
set -e
cd "$(dirname "$0")"
SJ=${SJASMPLUS:-sjasmplus}
command -v "$SJ" >/dev/null 2>&1 || SJ=/root/tools/sjasmplus/sjasmplus
mkdir -p build out src/gen
python3 tools/savemap.py            # where SAVE.DAT sits on the disk
python3 tools/gen.py                # the world: PCG, regions, rooms, ray-trees
python3 tools/audio.py              # music and sound effects
python3 tools/title.py              # title illustration
python3 tools/tmusic.py             # the three-voice title tune (into TITLE.BNK)
if [ -x "${FLITE:-/root/tools/flite/bin/flite}" ]; then python3 tools/speech.py; fi
(cd src && $SJ --nologo --lst=../build/main.lst --sym=../build/main.sym main.asm)
(cd src && $SJ --nologo --lst=../build/loader.lst loader.asm)
python3 tools/build_disk.py         # LANTERN.DS8
