#!/bin/sh
# per-update work statistics (cycles, excluding idle sound loop) over demo gameplay
cd "$(dirname "$0")/.."
L=$(awk '/^ *[0-9]+\+? +[0-9A-F]{4} .*play_act:/{f=1} f && /call present/{print $2; exit}' build/circus2.lst)
S0=$(tools/sym.sh snd_idle); S1=$(tools/sym.sh snd_tick)
./tools/vzemu build/CIRCUS2.VZ -f ${1:-2300} -hist ${2:-900} -slow $L 999999 -prof $S0 $S1 0 ${3:-} 2>&1 | grep "^U" | python3 -c "
import sys
v=sorted(int(l.split()[1]) for l in sys.stdin)
n=len(v)
print('updates',n,'mean',sum(v)//n,'p50',v[n//2],'p90',v[n*9//10],'p99',v[n*99//100],'max',v[-1],'over141k',sum(x>141000 for x in v))"
