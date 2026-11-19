# Killer Tomatoes 2 (Microbee Premium Plus) build:
#   art -> banked LZ assets -> KILLTOM2.COM -> outputs\KILLTPP.DS80
#   .\build.ps1          build
#   .\build.ps1 -Test    build, then run the boot and hardware-model regression tests
# Needs Python 3 with Pillow, and sjasmplus (work\tools\sjasmplus.exe or on PATH).
# The tests also need the "z80" package (pip install z80==1.2.0; a CPython 3.12
# build is kept in work\pylibs) and the owner's Microbee boot ROM at work\ubee\bn60.rom.
param([switch]$Test)
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot
$py = 'C:/Users/Owner/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe'
if ($env:KILLTOM_PYTHON) { $py = $env:KILLTOM_PYTHON } elseif (-not (Test-Path $py)) { $py = 'python' }
$asm = Join-Path $PSScriptRoot 'work\tools\sjasmplus.exe'
if (-not (Test-Path $asm)) { $asm = 'sjasmplus' }
# CP/M boot tracks + CCP.SYS: the bundled resources folder, else the owner's boot disk.
$base = if (Test-Path "$PSScriptRoot/resources/CCP.SYS") { "$PSScriptRoot/resources" } else { 'C:/Users/Owner/OneDrive/Documents/Microbee/DRVB.DS8' }

& $py work/premiumplus/tools/prepare_assets.py | Select-Object -Last 1
if ($LASTEXITCODE) { throw 'prepare_assets failed' }
New-Item -ItemType Directory -Force work/premiumplus/build, outputs | Out-Null
Push-Location work/premiumplus/src
& $asm --nologo --sym=../build/game.sym --lst=../build/game.lst main.asm
$rc = $LASTEXITCODE; Pop-Location
if ($rc) { throw "assembly failed ($rc)" }
& $py work/premiumplus/tools/make_disk.py $base outputs/KILLTPP.DS80
if ($LASTEXITCODE) { throw 'disk build failed' }
if ($Test) {
  & $py work/test_plus_boot.py; if ($LASTEXITCODE) { throw 'boot test failed' }
  & $py work/test_plus.py;      if ($LASTEXITCODE) { throw 'regression test failed' }
}
