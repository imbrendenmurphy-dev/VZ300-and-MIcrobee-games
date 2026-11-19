# Hamburger Sam II (Microbee Premium Plus) build
#   .\build.ps1            assemble COM only
#   .\build.ps1 -Assets    regenerate HAMSAM2.DAT (scenery + sprite cache) first
#   .\build.ps1 -Disk      also build outputs\HAMSAM2.DS80
# Needs sjasmplus (work\tools\sjasmplus.exe or on PATH) and Python 3.12 with
# Pillow (+ the "z80" package, pip install z80==1.2.0, for the tests).
param([switch]$Assets, [switch]$Disk)
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$py = 'C:\Users\Owner\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe'
if ($env:HAMSAM_PYTHON) { $py = $env:HAMSAM_PYTHON } elseif (-not (Test-Path $py)) { $py = 'python' }
$asm = Join-Path $root 'work\tools\sjasmplus.exe'
if (-not (Test-Path $asm)) { $asm = 'sjasmplus' }
Push-Location $root
try {
    if ($Assets) {
        & $py work\spectacle.py; if ($LASTEXITCODE) { throw 'spectacle failed' }
        & $py work\sprite_cache.py; if ($LASTEXITCODE) { throw 'sprite_cache failed' }
    }
    New-Item -ItemType Directory -Force work\port\build | Out-Null
    Push-Location work\port\src
    & $asm --nologo --msg=war --sym=..\build\game.sym --lst=..\build\game.lst main.asm
    $rc = $LASTEXITCODE
    Pop-Location
    if ($rc) { throw "assembly failed ($rc)" }
    "COM: " + (Get-Item work\port\build\HAMSAM2.COM).Length + " bytes"
    if ($Disk) { & $py work\build_disk.py; if ($LASTEXITCODE) { throw 'disk build failed' } }
} finally { Pop-Location }
