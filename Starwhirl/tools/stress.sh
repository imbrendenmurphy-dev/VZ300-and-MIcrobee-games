#!/bin/sh
# stress.sh [sector 0-4] -> frame-time histogram for a 60 s busy run with sound
SEC=${1:-4}
cd "$(dirname "$0")/.."
PRES=$(grep -E "^present:" build/starwhrl.sym | sed 's/.*0x0000//')
CS=$(grep -E "^cont_sec:" build/starwhrl.sym | sed 's/.*0x0000//')
PI=$(grep -E "^pips:" build/starwhrl.sym | sed 's/.*0x0000//')
LV=$(grep -E "^lives:" build/starwhrl.sym | sed 's/.*0x0000//')
P="-poke 30:$CS:$SEC"; for f in $(seq 200 100 2900); do P="$P -poke $f:$PI:3 -poke $f:$LV:3"; done
WLOG=1 ./tools/vzemu/vzemu build/STARWHRL.VZ -bennvenn -frames 3000 -keys tools/stress_keys.txt -watch $PRES $P "$@" 2>/tmp/stress.log
grep "^snow" /tmp/stress.log
grep "^w " /tmp/stress.log | awk '{f=substr($2,2)+0; if(f>150){ b=int(($3+35568)/71136); h[b]++; n++}} END{for(k in h) print k" fields:", h[k], int(100*h[k]/n)"%"}' | sort -n
