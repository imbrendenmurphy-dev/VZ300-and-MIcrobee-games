@echo off
rem Builds VZonPC.exe (the emulator window) and vzemu.exe (headless test runner)
rem with the C# compiler that ships with Windows (.NET Framework 4). No installs needed.
setlocal
cd /d "%~dp0"
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
set CORE=src\Z80.cs src\Z80Dis.cs src\Font6847.cs src\MfAudio.cs src\Tape.cs src\Machine.cs src\SdCard.cs src\Trace.cs src\Vis.cs src\Headless.cs
set REFS=-r:System.Drawing.dll -r:System.Windows.Forms.dll -r:Microsoft.VisualBasic.dll

"%CSC%" -nologo -optimize+ -target:exe -out:vzemu.exe -main:Headless %REFS% %CORE%
if errorlevel 1 exit /b 1
"%CSC%" -nologo -optimize+ -target:winexe -out:VZonPC.exe -main:VzApp -win32icon:src\vz.ico %REFS% %CORE% src\WinIO.cs src\MainForm.cs src\SdBrowser.cs
if errorlevel 1 exit /b 1
echo Built VZonPC.exe and vzemu.exe
