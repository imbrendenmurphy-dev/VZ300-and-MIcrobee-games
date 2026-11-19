# MAX Q v0.12 — speed: 16.5 fps -> about 24.3 fps

Measured in the cycle-exact emulator during a race (autopilot), same track and gameplay as v0.11c.

| | cycles per frame | fps |
|---|---|---|
| v0.11c | ~212,000 | 16.5 |
| v0.12 | ~146,000 (about 7,000 of it waiting for a field) | 24.3 |

Fields per frame in the race: 2 fields (25 fps) for ~78% of frames, 3 fields for ~14%; the rest
catch up in 1. 25 fps needs a frame to fit in 2 fields = 141,260 cycles.

## What changed
1. **Road builder rewritten** (`road_new.asm`): bend, slide and hill sums live in registers
   (HL' x, DE' dx, BC' slide, IX h, IY dh); slide step is a constant added each slot.
2. **One span list per depth slot** instead of one per screen row: rows point at their slot's list
   (`RLPL/RLPH`), and the dither half of odd rows comes from the pattern page (`RDP0O/RDP1O`),
   so a list no longer depends on the row.
3. **Caches**: a slot's list is rebuilt only if its centre or surface changed; a slot whose centre,
   section and rows are all unchanged is skipped entirely; sky lists only when the horizon moves;
   the mountains only when the heading or horizon moves (or something was drawn over them).
4. **Only changed road rows are recomposed**: a row is redrawn if its list/page changed or a sprite,
   rectangle or banner was drawn over it last frame (sprites mark `OVR`).
5. **Mountain rows are not composed** (the mountains overwrite them whole).
6. **Screen copy**: fully unrolled stack copy (204 cycles per 16 bytes, was 244), and only rows that
   changed since the last copy are copied (`COPYD` / `OVR`). With a colour split on (attract,
   HUD strip) every row is copied so the split timing stays fixed; the split still lands on
   scanline 221 as before.
7. **HUD** redraws only the characters that changed, and copies only its own rows.
8. Smaller ones: sorted sprite list instead of the depth-mark table; objects checked for
   visibility before the collected-bit lookup; transparent text uses a pre-masked font.

## Checks
- `build_race.py test`: 34/34 frames byte-identical with `road_ref.py`, including 16 multi-frame
  sequences that exercise the caches (driving onto pads, ramps and the start line).
- Debug build comparing the whole screen with the buffer after every copy, 150 s (attract, a full
  race, standings, next race): 0 mismatching bytes. (The same check with the copy deliberately
  broken reports tens of thousands, so it does catch errors.)
- Full autopilot race completes.

## Where the time goes now (per race frame)
Road builder ~44K, composer ~40K, screen copy ~17K, sprites ~6K, mountains ~4K, game logic ~20K.
The remaining 3-field frames come from busy moments (steering + several sprites + banners).
