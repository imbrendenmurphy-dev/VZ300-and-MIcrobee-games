# OCTOCHROME
### v0.1 · all 8 colours at once in the VZ300's 128×64 mode · VIBED BY BPM 2026

A raster demo inspired by Dave's split-CSS experiments in the VZ200 / VZ300 / Laser 210 / 310 group. The
colour set (CSS) is switched in the middle of every scanline, so colour set 0 (green, yellow, blue, red)
and colour set 1 (buff, cyan, magenta, orange) share the screen. A big scroller greets Dave and the crew.
It bounces with **real FLD**: a mode flick in the horizontal blanking makes the 6847 repeat a line, so the
text drops without moving a byte. The tune is mixed into the same cycle-exact loop (three voices, one
sample every two scanlines). Standard VZ300, no expansion. `release/OCTO.VZ`, 9.8K, runs at $8000.

| Screen | What happens |
|---|---|
| Logo "VZ200 VZ300 / LASER 210 310" | colour-set bands 16 lines tall roll down through it (and the border) |
| Scroller | FLD bounce; left of a moving split it is yellow on blue, right of it cyan on magenta |
| Colour bars | two bands with opposite palettes, their splits swinging opposite ways: 8 colours |
| Title "OCTOCHROME" | colour set 1, while the CPU does the frame's work |

## Fine phase (keys `,` and `.`)
The split is placed to 1 T-state (1 pixel). That needs the program to know, to the T-state, when field
sync ends. It samples FS at one exact moment: the **fine phase**, 0-15, default 14. Pressing `,` or `.`
changes it, and the number shows at the bottom right for 3 seconds. 14 is right for VZonPC. A real Z80
reads memory later in the instruction than the emulator assumes, so **on a real VZ300 the best value is
probably near 2**. If the right-hand edges of the split shimmer, step through the values. The split is
steadiest at the right one. Please report the number so the next version can default to it.

## How it works
- Frame = 312 lines × 228 T. An IM2 interrupt (257-byte table at $B500, handler at $B6B6) wakes a HALT at
  field sync (0-3 T jitter). Then the code runs a chain of **kernel units**, 456 T each (two scanlines),
  entered by RET from a table on the stack. Each unit pops the next unit's two latch bases
  (W1 = line start, W2 = mid-line) and RETs on.
- Unit 28 is the **fine-sync unit**. It reads FS at the end of field sync (line 56) and takes a path
  2 T shorter if it is already high, which trims the jitter to 1 T.
- In each line: W1 (`LD (HL),C` / `LD (HL),B` in the blanking: a flick if C has AG off), voice mixing,
  and a 17-byte region of 16 NOPs and one `LD (HL),C` (the split write). The split moves by moving that one
  byte (4 pixels a step).
- The bottom 38 lines run the frame's work: music tick + patch the steps and duties into the 4 unit copies,
  FLD amount, splits, scroller (one byte every other field), logo bands, keys. Then EI / HALT.
- `py octo\build.py` builds everything. It generates the kernel and asserts each unit is exactly 456 T.

## Checked (in vzemu / VZonPC only)
- The split write lands on T 127/128 on every frame (1 T jitter). A phase 6 steps off shows all 4
  values, so the fine sync works.
- No crash; audio is steady; the VZonPC window runs at 50 fps.
- **Not yet tried on a real VZ300.**
