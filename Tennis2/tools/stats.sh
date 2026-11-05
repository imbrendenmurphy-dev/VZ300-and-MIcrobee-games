#!/bin/sh
# usage: tools/stats.sh frames keysfile  -> counts of match events under autoplay
cd "$(dirname "$0")/.."
AP=$(grep " autoplay$" build/tennis2.sym | cut -d' ' -f1)
for l in serve_hit do_fault do_fault.double make_shot point_won ball_bounce.out ball_update.netted ball_bounce.second ball_move.gone game_won; do
  a=$(grep " $l$" build/tennis2.sym | cut -d' ' -f1)
  n=$(tools/vzemu/vzemu build/TENNIS2.VZ -frames $1 -keys $2 -poke 400:$AP:1 -watch $a 2>&1 | grep '^watch' | awk '{print $4}')
  echo "$l ${n:-0}"
done
