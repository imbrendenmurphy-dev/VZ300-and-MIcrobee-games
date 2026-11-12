#!/bin/sh
# Build VZ-DECK: the shell, the player plug-ins and the patched DOS.
# Needs Python 3. Output goes to src/out/.
set -e
cd "$(dirname "$0")"
mkdir -p out
python3 build.py                 # SHELL.VZ (browser + MIDI/MOD player)
python3 bplug.py pt3 psg s3m xm vgm   # PLAYPT3.VZ, PLAYPSG.VZ, PLAYS3M.VZ, PLAYXM.VZ, PLAYVGM.VZ
# The DOS patch needs your own copy of BennVenn VZDOS 2.31/2.32:
if [ -f ../testfiles/VZDOS.VZ ]; then python3 patchdos.py ../testfiles/VZDOS.VZ out/VZDOS.VZ; fi
