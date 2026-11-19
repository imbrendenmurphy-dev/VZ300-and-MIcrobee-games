@echo off
rem REDBACK build on Windows: runs build.sh unchanged with the bash that comes
rem with GitHub Desktop (or Git for Windows). Needs Python 3 ("py") + numpy + Pillow.
rem Tests: cd tools, then  py scrolltest.py / py sprtest.py / py perf.py / py combattest.py
rem (the emulator DLL is built on first use with TinyCC in tools\tcc - see CLAUDE.md).
setlocal
set "SH="
for /d %%D in ("%LOCALAPPDATA%\GitHubDesktop\app-*") do if exist "%%D\resources\app\git\usr\bin\sh.exe" set "SH=%%D\resources\app\git\usr\bin\sh.exe"
if not defined SH if exist "%ProgramFiles%\Git\usr\bin\sh.exe" set "SH=%ProgramFiles%\Git\usr\bin\sh.exe"
if not defined SH (
  echo No bash found: install GitHub Desktop or Git for Windows.
  exit /b 1
)
cd /d "%~dp0"
"%SH%" -c "export PATH=\"$PWD/tools/win:/usr/bin:$PATH\"; ./build.sh"
