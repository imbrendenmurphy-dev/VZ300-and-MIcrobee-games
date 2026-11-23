# Measure uBee512's CPU use while RUNE AMOK's title music plays.
# Launches uBee512 on a copy of the disk, types RUNEAMOK at A>, waits for the
# title, samples the process's CPU time, then closes it.
param([string]$Disk = "$PSScriptRoot\..\release\RUNEAMOK.DS8", [int]$Wait = 28)
$ubee = "C:\Users\Owner\Documents\Codex\2026-11-17\c-users-owner-documents-killertomatoes-vz300-2\work\ubee"
Copy-Item $Disk "$ubee\RUNEAMOK-cpu.ds80" -Force
$p = Start-Process "$ubee\ubee512.exe" -WorkingDirectory $ubee -PassThru -ArgumentList @(
    '--config=none', '--model=p1024k', '--pcg=32', '--vdu=2', '--rom1=bn60.rom', '--rom2=none', '--rom3=none',
    '-a', "`"$ubee\RUNEAMOK-cpu.ds80`"", '--exit-check=off')
Start-Sleep -Seconds 6
$sh = New-Object -ComObject WScript.Shell
[void]$sh.AppActivate($p.Id)
Start-Sleep -Milliseconds 500
$sh.SendKeys('RUNEAMOK~')
Start-Sleep -Seconds $Wait
$p.Refresh()
$c1 = $p.TotalProcessorTime.TotalMilliseconds
Start-Sleep -Seconds 6
$p.Refresh()
$c2 = $p.TotalProcessorTime.TotalMilliseconds
"{0:N0}% of one core while the title music plays" -f (($c2 - $c1) / 60)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public struct RECT { public int L, T, R, B; }
public static class W { [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r); }
"@
$r = New-Object RECT
[void][W]::GetWindowRect($p.MainWindowHandle, [ref]$r)
$bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.CopyFromScreen($r.L, $r.T, 0, 0, $bmp.Size)
$bmp.Save("$PSScriptRoot\..\build\ubee_window.png")
$p | Stop-Process -Confirm:$false
