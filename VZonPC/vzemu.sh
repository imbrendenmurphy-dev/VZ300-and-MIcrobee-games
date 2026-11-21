#!/bin/sh
# vzemu (the headless test runner) on Linux and macOS, with modern .NET or Mono: ./vzemu.sh script.txt
DIR=$(cd "$(dirname "$0")" && pwd)
if command -v dotnet >/dev/null 2>&1 && dotnet --list-runtimes 2>/dev/null | grep -q '^Microsoft.NETCore.App'; then
  exec dotnet "$DIR/vzemu.exe" "$@"
elif command -v mono >/dev/null 2>&1; then
  exec mono "$DIR/vzemu.exe" "$@"
else
  echo "vzemu needs the .NET runtime (Fedora: sudo dnf install dotnet-runtime-8.0) or Mono." >&2
  exit 1
fi
