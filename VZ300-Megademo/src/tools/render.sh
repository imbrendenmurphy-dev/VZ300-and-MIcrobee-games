#!/bin/bash
# render.sh out.mp4 seconds [extra emulator args]
OUT=$1; SECS=$2; shift 2
cd /root/vzmega/build
T=/tmp/claude-0
../tools/vzemu VZMEGA.VZ -sd VZMEGA.DAT -t $SECS -wav $T/render.wav -vid /dev/stdout "$@" 2>$T/render.log | \
  ffmpeg -loglevel error -y -f rawvideo -pix_fmt rgb24 -s 320x240 -r 49.86 -i - -vf scale=640:480:flags=neighbor -c:v libx264 -preset veryfast -crf 18 -pix_fmt yuv420p $T/render_v.mp4
ffmpeg -loglevel error -y -i $T/render_v.mp4 -i $T/render.wav -c:v copy -c:a aac -b:a 160k -shortest $OUT
tail -2 $T/render.log
