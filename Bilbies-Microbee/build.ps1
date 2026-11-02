param(
    [string]$Python = 'python',
    [string]$BaseDisk = (Join-Path $PSScriptRoot '..\LanternDeep\release\LANTERN.DS8'),
    [switch]$Bootstrap
)
$ErrorActionPreference = 'Stop'
if ($Bootstrap) {
    & $Python (Join-Path $PSScriptRoot 'tools\bootstrap.py')
    if ($LASTEXITCODE -ne 0) { throw 'Tool bootstrap failed' }
}
$env:PATH = (Join-Path $PSScriptRoot '.tools') + ';' + $env:PATH
& $Python (Join-Path $PSScriptRoot 'tools\build.py')
if ($LASTEXITCODE -ne 0) { throw 'Assembly failed; no release produced' }
& $Python (Join-Path $PSScriptRoot 'tools\disk.py') --base $BaseDisk
if ($LASTEXITCODE -ne 0) { throw 'Disk build failed' }
Write-Output (Join-Path $PSScriptRoot 'build\BILBIES.DS8')
