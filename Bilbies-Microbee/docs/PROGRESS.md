# Progress log

## 2026-11-06 / 07

- **Reviewed the Codex attempt.** It kept a VZ-style framebuffer
  converted to PCG every frame, which was too slow, and the art was
  scaled-up VZ art. I started again with a Microbee-native design and
  kept only the CP/M loader and disk-building ideas.
- **Engine.** A PCG bitmap playfield (a glyph per cell, two pages, page
  flip). The world is drawn at 2× with a colour map. Sprites are blitted
  into the glyphs, and dirty columns are restored from the world bitmap.
  The game updates at 12.5 Hz and draws at 25 fps with interpolation.
- **Rules.** The VZ `game.asm` is used as is. A reference harness checks
  every level tick by tick. All 24 levels match and all are won by their
  solutions.
- **Speed work.** Dirty-column lists, restore tables, unrolled copies,
  frame pacing on 6545 blanking edges, and adaptive in-between frames.
- **Front end.** Monitor choice, live title scene on the logo, attract
  mode, level select, briefing with minimap, results, finale, settings,
  and the trainer.
- **Disk.** CP/M loader `BILBIES.COM`; packed levels (LZB); a DS80 image
  with no Shell; saving to `SAVE.DAT` with write-protect and error
  handling.
- **Fixed on the real-boot path:**
  - Game variables weren't cleared (real RAM isn't zero), so the trainer
    switched itself on.
  - CP/M's BIOS overwrote block 3 (the HUD graphics); moved to block 27.
  - The IM 2 vector table and bounce buffer overlapped the game
    variables; the assembler now checks for this.
- **Mouse.** Interrupt-driven Microsoft serial (uBee512 wiring), tested
  in the model.
- **Art.** Levels, 50 Australiana pictures and the bilbies redrawn for
  the Microbee's resolution and cell colours, with a mono version. Also
  fixed a scrolling bug that loaded the wrong world columns (it made
  every level look blocky).
- **Sound.**
  - The VZ effects, through speaker service calls calibrated per call
    site in the model.
  - The VZ's three-voice music player ported: title (Grieg), briefing,
    win and lose jingles.
  - Music on/off setting, saved.
- **Documents.** README, verification report, handover.

## 2026-11-07 (after the first real-hardware run)

- **Real hardware result.** It runs on the user's Premium Plus with the
  amber monitor. The title was choppy; the attract gameplay was fine.
- **Title fixed.** The music could play past an uncounted frame edge.
  The wait loops now count the edge first, and with music on the title
  draws at 12.5 fps, so the music gets over half the time.
- **Speed.**
  - The original's blocker test scanned all 40 creature slots for every
    walker step. It now scans only the slots in use, with a tighter loop
    and the same results (checked on all 24 levels).
  - The status line is rebuilt every other frame instead of every frame.
  - In mono, the bilbies' cells are no longer recoloured, since mono
    inks are always bright.
  - More frame-edge checks in long stretches.

## Next

- On the real Premium Plus: saving, mouse, joystick, sound, the title
  after the fix.
- Speed on the 30–40 bilby levels.
- The yellow-ledge clash.
