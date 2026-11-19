# Porting DROPBEAR 3D to the Sharp MZ-700

Source: `C:\Users\Owner\Documents\Dropbear3D_VZ300` (VZ300 v0.4), which we only read from.
Target: one MZT for a stock 64K MZ-700, rendered by the MZRAY colour-cell raycaster.

## What carries over and what changes

| DROPBEAR 3D (VZ300) | MZ-700 port |
|---|---|
| 9 areas, each a 16×16 map, page-aligned, cell = y*16+x | **Same format as MZRAY's MAP page.** The area data (`AREAS` in DROPBEAR's build.py) ports almost unchanged |
| Cell values: 1 wall A, 2 wall B, 3 door, 4 exit, 5 wall C, 6 locked, 7/8 switch, 9 gate, 10 cracked | Same values. MZRAY's `texl = ((type-1)*2+side)*8+u` covers types 1–16, so all 10 fit in the existing TEX pages |
| Blocking furniture sets bit 7 of the map cell, so rays have to `and 7Fh` | Goes in a separate **collision page** instead, so the DDA inner loop stays exactly as it is |
| 16×16 2bpp textures, 4 per theme, copied from the high bank | Redrawn at 8×8 in MZ colours (1 byte per texel), with a darker set for Y-sides. Each theme's 4 are copied into the TEX pages on entering an area |
| Sky/ground colour per theme | Poke the `CEIL`/`FLOOR` immediates in the column drawers (self-modifying, like the rest of MZRAY) |
| Fog in mine/swamp/lair | Columns past the fog distance draw a fog texture. Later step |
| 1024-unit angles, 32 rays, 48-row view, compiled scalers | Kept as MZRAY's 256-unit angles, 20 or 40 rays and 22-row view, chosen after the real-hardware test |
| Sprites: prescaled ladders in two RAM banks | Colour-cell sprites. At 22 rows they're tiny next to the VZ versions, so a full ladder may fit in main RAM. Otherwise scale at run time from one 16×16 source |
| Object list (8 bytes × 32), AI, pickups, bosses, particles | Game logic ports almost line for line. Only the drawing changes |
| 1-bit speaker: the CPU busy-waits for every beep | **8253 timer:** set a frequency and the tone plays with no CPU time. That's a big speed-up for in-game sound. Title music uses fast arpeggios on the one channel |
| Saved state per area in the high bank (512 bytes × 9) | 4.5K in main RAM, no banking needed |
| Keys W S A D Q E SPACE M and joystick | Same keys via the MZ matrix: W row2 b1, S row2 b5, A row4 b7, D row4 b4, Q row2 b7, E row4 b3, M row3 b3, SPACE row6 b3. Cursor keys also work. **Unverified on hardware** |

## The one design question that touches the raycaster

In **direct** mode, walls go straight to colour RAM. If sprites, the gun and pieces are drawn on top
afterwards, each one is missing from the screen for most of a frame, so it flickers. There are two fixes:

1. **Composite per column (recommended):** project the visible objects before casting. For each column,
   draw the wall slice and then, straight away, any sprite slices that are nearer than the wall in that
   column. The flicker window shrinks to microseconds and there's no buffer copy.
   This needs `render` to store each column's distance and call a sprite-slice drawer, which changes the raycaster loop.
2. **Buffered mode:** no flicker, but it was ~10% slower in the emulator.

I'll ask before changing `render`/`castray` for this.

## Steps

1. **Done (v0.1): world walkabout.** All nine areas with themes, textures, sky/ground colours, doors, exits between
   areas, locked doors and keys, switches and gates, secret walls, blocking furniture, the HUD and messages.
   Uses the MZRAY raycaster unchanged.
2. **Done (v0.2): sprites, creatures, shooting.** Per-column compositing (approved), with all 23 object types drawn
   from DROPBEAR's shapes. AI is ported (sleep, wake, chase, bite, bursts, faster when hurt), along with the
   blaster, flinch and kill, bosses opening gates, death and respawn, and placeholder 8253 beeps.
3. **Done (v0.3): exploding pieces, flashes, sound.** 32 pieces drawn per column, with gravity and bounce.
   There's a red bite flash and a white boss flash, a chained-part 8253 effects engine with per-column noise,
   DROPBEAR's in-game tune, and the death and win jingles.
4. **Done (v0.4): automap, fog, win text.** Death and respawn were already done in v0.2.
5. **Done (v0.5): attract loop.** Colour-cell arched logo with drips, DROPBEAR's three-voice title music arpeggiated
   per field on the 8253, a ten-creature gallery with fanfares (punctuation-free text), the autopilot demo
   cycling through the areas, and an intro page.
6. Fit, pack and load-time check through UniCMT.

## Open questions for the user
- Real MZ-700 benchmark photos (decides 20 vs 40 rays).
- Whether the keys work on real hardware.
- How long UniCMT takes to load a large MZT (decides whether to compress).
