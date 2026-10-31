#!/bin/sh
# run.sh NFRAMES  -> frames.bin out.wav ticks.txt tickhist.txt sites.txt
A=""
for n in snd snd2 snd3 snd4 snd5 snd6 snd7 snd8; do
  a=$(grep -E " $n:" demo.lst | head -1 | awk '{print $2}'); A="$A,$a"
done
A=${A#,}
SNDI=$(grep -E " sndi:" demo.lst | head -1 | awk '{print $2}') START=8000 ./vzemu emu.vz ${1:-3000} frames.bin out.wav $A ticks.txt
