@echo off
rem Killer Tomatoes 2 - Microbee Premium Plus (1 MB RAM, 32 KB PCG) in uBee512 6.0.0.
rem Runs a working copy so the release disk is never written to. At A> type KILLTOM2
rem Set UBEE to your uBee512 folder (it must contain ubee512.exe and bn60.rom).
if "%UBEE%"=="" set UBEE=C:\Users\Owner\Documents\Codex\2026-11-17\c-users-owner-documents-killertomatoes-vz300-2\work\ubee
if not exist "%UBEE%\ubee512.exe" (echo uBee512 not found in %UBEE% & pause & exit /b 1)
copy /y "%~dp0KILLTOM2.DS80" "%UBEE%\KILLTOM2-play.ds80" >nul
cd /d "%UBEE%"
start "Killer Tomatoes 2" ubee512.exe --config=none --model=p1024k --pcg=32 --vdu=2 --rom1=bn60.rom --rom2=none --rom3=none -a "%UBEE%\KILLTOM2-play.ds80" --exit-check=off
