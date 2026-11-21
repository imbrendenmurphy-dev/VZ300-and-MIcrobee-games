#!/bin/sh
# VZonPC on Linux and macOS: runs VZonPC-SDL.exe with modern .NET (8 or later) or with Mono.
# Needs SDL2, and ffmpeg for MP3/FLAC/Ogg tapes. On Fedora:
#   sudo dnf install dotnet-runtime-8.0 SDL2 ffmpeg-free zenity
# Any arguments are passed on (a .VZ file, --machine vz200, --cart disk, --tape FILE ...; see README.md).
DIR=$(cd "$(dirname "$0")" && pwd)
if command -v dotnet >/dev/null 2>&1 && dotnet --list-runtimes 2>/dev/null | grep -q '^Microsoft.NETCore.App'; then
  exec dotnet "$DIR/VZonPC-SDL.exe" "$@"
elif command -v mono >/dev/null 2>&1; then
  exec mono "$DIR/VZonPC-SDL.exe" "$@"
else
  echo "VZonPC needs the .NET runtime (Fedora: sudo dnf install dotnet-runtime-8.0;" >&2
  echo "Ubuntu: sudo apt install dotnet-runtime-8.0; macOS: brew install dotnet) or Mono." >&2
  exit 1
fi
