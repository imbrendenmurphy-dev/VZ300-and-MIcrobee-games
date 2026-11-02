param(
    [string]$Python = 'python',
    [string]$BaseDisk = (Join-Path $PSScriptRoot '..\LanternDeep\release\LANTERN.DS8'),
    [switch]$Bootstrap,
    [switch]$CompatibilityBaseline
)
$ErrorActionPreference = 'Stop'
if ($Bootstrap) {
    & $Python (Join-Path $PSScriptRoot 'tools\bootstrap.py')
    if ($LASTEXITCODE -ne 0) { throw 'Tool bootstrap failed' }
}
$env:PATH = (Join-Path $PSScriptRoot '.tools') + ';' + $env:PATH
if ($CompatibilityBaseline) {
    & $Python (Join-Path $PSScriptRoot 'tools\build.py')
    if ($LASTEXITCODE -ne 0) { throw 'Baseline assembly failed' }
    & $Python (Join-Path $PSScriptRoot 'tools\disk.py') --base $BaseDisk
    if ($LASTEXITCODE -ne 0) { throw 'Baseline disk build failed' }
    Write-Output (Join-Path $PSScriptRoot 'build\BILBIES.DS8')
} else {
    & $Python (Join-Path $PSScriptRoot 'native\build.py') --base $BaseDisk
    if ($LASTEXITCODE -ne 0) { throw 'Native renderer build failed' }
    Write-Output (Join-Path $PSScriptRoot 'build\native\BILBIES-NATIVE.DS8')
}
