# Launch uBee512 as a Premium Plus with a disk, send keys, and capture its window.
# Keys are posted straight to the emulator window and frames are grabbed with PrintWindow,
# so it works behind other windows and never takes keyboard focus from the desktop.
# Usage: emu_capture.ps1 -Disk <ds80> -Out <prefix> -Steps "wait:8,type:KILLTOM2~,until:60,shot:title"
#   wait:<s>   type:<text> (~ = RETURN, _ = SPACE)   hold:<hexVK>/<ms>   shot:<name>
#   until:<s>  wait up to s seconds for the window to change size (video mode switch)
param([string]$Disk, [string]$Out, [string]$Steps, [string]$Model = "p1024k", [int]$Pcg = 32)
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System; using System.Runtime.InteropServices;
public class W {
  [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
  [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
  [DllImport("user32.dll")] public static extern bool PostMessage(IntPtr h, uint msg, IntPtr w, IntPtr l);
  [DllImport("user32.dll")] public static extern uint MapVirtualKey(uint code, uint type);
  [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)] public static extern int GetClassName(IntPtr h, System.Text.StringBuilder s, int n);
  public delegate bool EnumProc(IntPtr h, IntPtr l);
  [DllImport("user32.dll")] public static extern bool EnumWindows(EnumProc f, IntPtr l);
  [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h, out uint pid);
  public static IntPtr FindSdl(uint pid) {
    IntPtr found = IntPtr.Zero;
    EnumWindows(delegate(IntPtr h, IntPtr l) {
      uint p; GetWindowThreadProcessId(h, out p);
      var s = new System.Text.StringBuilder(64); GetClassName(h, s, 64);
      if (p == pid && s.ToString() == "SDL_app") { found = h; return false; }
      return true; }, IntPtr.Zero);
    return found;
  }
  public struct RECT { public int L, T, R, B; }
}
"@
$ubee = Join-Path $PSScriptRoot "ubee"
$disk = (Resolve-Path $Disk).Path
$Out = [System.IO.Path]::GetFullPath((Join-Path (Get-Location).Path $Out))
$args = "--config=none --model=$Model --pcg=$Pcg --vdu=2 --rom1=bn60.rom --rom2=none --rom3=none -a `"$disk`" --exit-check=off --sdl-putenv=SDL_VIDEODRIVER=windib"
$p = Start-Process -FilePath (Join-Path $ubee "ubee512.exe") -WorkingDirectory $ubee -ArgumentList $args -PassThru -WindowStyle Minimized
$h = [IntPtr]::Zero   # the SDL display window, not uBee512's console window
for ($i = 0; $i -lt 80 -and $h -eq [IntPtr]::Zero; $i++) {
  Start-Sleep -Milliseconds 250; $h = [W]::FindSdl([uint32]$p.Id)
}
if ($h -eq [IntPtr]::Zero) { Stop-Process -Id $p.Id -Force; throw 'uBee512 display window not found' }
[W]::ShowWindow($h, 4) | Out-Null   # SW_SHOWNOACTIVATE: visible for PrintWindow, but not focused
function Key([int]$vk, [int]$hold = 80) {
  $sc = [W]::MapVirtualKey($vk, 0)
  [W]::PostMessage($h, 0x100, [IntPtr]$vk, [IntPtr](1 -bor ($sc -shl 16))) | Out-Null
  Start-Sleep -Milliseconds $hold
  [W]::PostMessage($h, 0x101, [IntPtr]$vk, [IntPtr]((1 -bor ($sc -shl 16)) -bor 0xC0000000)) | Out-Null
  Start-Sleep -Milliseconds 80
}
function Size { $r = New-Object W+RECT; [W]::GetClientRect($h, [ref]$r) | Out-Null; return $r }
function Shot([string]$name) {
  $r = Size; $bmp = New-Object System.Drawing.Bitmap ($r.R - $r.L), ($r.B - $r.T)
  $g = [System.Drawing.Graphics]::FromImage($bmp); $dc = $g.GetHdc()
  [W]::PrintWindow($h, $dc, 1) | Out-Null   # PW_CLIENTONLY
  $g.ReleaseHdc($dc); $bmp.Save("$Out-$name.png"); $g.Dispose(); $bmp.Dispose()
  Write-Output "shot $Out-$name.png $($r.R)x$($r.B)"
}
try {
  foreach ($s in $Steps.Split(',')) {
    $k, $v = $s.Split(':', 2)
    switch ($k) {
      'wait' { Start-Sleep -Milliseconds ([int]([double]$v * 1000)) }
      'shot' { Shot $v }
      'type' { foreach ($ch in $v.ToCharArray()) {
                 if ($ch -eq '~') { Key 0x0D } elseif ($ch -eq '_') { Key 0x20 } else { Key ([int][char]([string]$ch).ToUpper()) } } }
      'hold' { $vk, $ms = $v.Split('/'); Key ([Convert]::ToInt32($vk, 16)) ([int]$ms) }
      'until' {
        $sw = [Diagnostics.Stopwatch]::StartNew(); $w0 = (Size).R
        do { Start-Sleep -Milliseconds 250 } while ((Size).R -eq $w0 -and $sw.Elapsed.TotalSeconds -lt [double]$v)
        Write-Output ("mode switch after {0:N1} s" -f $sw.Elapsed.TotalSeconds) }
    }
  }
} finally { Stop-Process -Id $p.Id -Force -ErrorAction SilentlyContinue }
