#!/bin/sh
# 2018 A.D. by Five Finger Punch (Edison 2018), played from its CD audio like the real thing, on Linux or macOS:
# a VZ200 with no expansion types CRUN, and the audio plays into the tape socket (data on the left channel,
# music on the right through your speakers). --no-settings keeps your usual VZonPC setup.
# Put 2018AD_combined.wav next to this file, or the demo's own combined.ogg (that one needs ffmpeg).
DIR=$(cd "$(dirname "$0")" && pwd)
TAPE="$DIR/2018AD_combined.wav"
[ -f "$TAPE" ] || TAPE="$DIR/combined.ogg"
if [ ! -f "$TAPE" ]; then
  echo "2018AD_combined.wav is missing. Download 2018 A.D. by Five Finger Punch from scene.org and put its" >&2
  echo "combined.ogg next to this file (or convert it to WAV and save it as 2018AD_combined.wav)." >&2
  exit 1
fi
exec "$DIR/vzonpc.sh" --no-settings --machine vz200 --exp none --type 'CRUN\r' --tape "$TAPE"
