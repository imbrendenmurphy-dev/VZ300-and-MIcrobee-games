# BLACKOUT PROTOCOL (Microbee Premium Plus) build
#   .\build.ps1          generate assets, assemble BLACKOUT.COM, build outputs\BLACKOUT.DS80
param([switch]$NoDisk)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$py = 'C:\Users\Owner\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
if (-not (Test-Path $py)) { $py = 'python' }
Push-Location $root
try {
    & $py tools\gen.py; if ($LASTEXITCODE) { throw 'gen failed' }
    & $py tools\reach.py | Out-Null; if ($LASTEXITCODE) { & $py tools\reach.py; throw 'a room has unreachable places' }
    Push-Location src
    & ..\tools\sjasmplus.exe --nologo --msg=war --sym=..\build\game.sym --lst=..\build\game.lst main.asm
    $rc = $LASTEXITCODE
    Pop-Location
    if ($rc) { throw "assembly failed ($rc)" }
    Push-Location src
    & ..\tools\sjasmplus.exe --nologo --msg=war autoboot.asm      # disk A's auto-boot CCP.SYS
    & ..\tools\sjasmplus.exe --nologo --msg=war fdctest.asm       # the test disk's FDCTEST.COM
    $rc = $LASTEXITCODE
    Pop-Location
    if ($rc) { throw "autoboot assembly failed ($rc)" }
    "COM: " + (Get-Item build\BLACKOUT.COM).Length + " bytes"
    if (-not $NoDisk) { & $py tools\build_disk.py; if ($LASTEXITCODE) { throw 'disk build failed' } }
} finally { Pop-Location }
