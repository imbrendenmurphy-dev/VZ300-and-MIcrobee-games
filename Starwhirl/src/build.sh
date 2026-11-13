#!/bin/sh
# STARWHIRL build: needs python3 and sjasmplus on your PATH (or SJASMPLUS=/path/to/sjasmplus)
set -e
cd "$(dirname "$0")"
mkdir -p ../build
python3 gfx.py gfx.inc
python3 music.py music.inc
python3 tables.py tables.inc
${SJASMPLUS:-sjasmplus} --nologo --msg=war --sym=../build/starwhrl.sym main.asm
python3 mkvz.py starwhrl.bin ../build/STARWHRL.VZ "STARWHIRL" 8000
