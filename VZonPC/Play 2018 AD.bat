@echo off
rem 2018 A.D. by Five Finger Punch (Edison 2018), played from its CD audio like the real thing:
rem a VZ200 with no expansion types CRUN, and the audio plays into the tape socket (data on the left
rem channel, music on the right through your speakers). --no-settings keeps your usual VZonPC setup.
rem Runs from whatever folder this file is in, so the folder can be zipped up and moved.
if not exist "%~dp02018AD_combined.wav" (
  echo 2018AD_combined.wav is missing. Download 2018 A.D. by Five Finger Punch from scene.org,
  echo convert its combined.ogg to WAV, and save it next to this file as 2018AD_combined.wav.
  pause
  exit /b 1
)
start "" /D "%~dp0." "%~dp0VZonPC.exe" --no-settings --machine vz200 --exp none --type "CRUN\r" --tape "%~dp02018AD_combined.wav"
