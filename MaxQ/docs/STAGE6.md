# MAX Q — v0.9: the MAX Q CUP
*VIBED BY BPM 2026*

## Speed

| Change | Fields per frame | fps (emulator) |
|---|---|---|
| v0.8 | 4.77 | 10.5 |
| Track sides (rails) removed: a clean floating track | 4.51 | 11.1 |
| Coarser detail 4–10 sections ahead (no visible difference) | 4.21 | 11.9 |
| **v0.9 with everything below** | **4.64** | **10.8** |

Making room: the track tables moved into SRAM bank B, and the sprite source plus the track are loaded above $E800 and moved into the bank at start-up. MAXQ.VZ now loads $8000–$F79A, the same kind of range as Dawn Patrol 2. That freed about 5 KB of main memory for the new code.

The new gameplay costs about 0.4 fields per frame. Most of that is rivals and objects being placed during the transform; a per-depth lookup cut that hook from 8,500 to under 1,000 T.

## Gameplay

- **MAX Q CUP:** 4 races of 3 laps against **VOLT** (red team, aggressive), **NOVA** (blue team, the quickest clean racer) and **RAZE** (red team, lays mines).
  - Races 2 and 4 are **dusk races**: the whole screen switches to colour set 1, at no cost.
  - The rivals get a little quicker each round.
  - Points are 10 / 6 / 3 / 1. After each race you get the results card, then the standings, then the next race's intro card. After race 4, the champion card.
- **Pickups** float above the track, 16 per lap; they come back each lap:
  - **Yellow pod:** boost.
  - **Blue pod:** energy, +32 shield.
  - **Red pod:** missile.
  - **Red/blue pod:** mine.
- **Weapons:** one at a time, shown on the HUD. **M or joystick fire** uses it.
  - **Missile:** flies ahead and homes on the nearest rival up to 16 sections ahead. A hit halves its speed and it spins out (flickers).
  - **Mine:** dropped behind you. A rival that runs over it spins out.
- **Rival tricks:**
  - VOLT fires a missile at you when it's 1–7 sections behind, at most once every ~20 s. Jumping dodges it.
  - RAZE drops a mine ahead of you when it's 3–10 sections in front.
  - Being hit halves your speed and costs 8 shield. It's never fatal.
- **Boost arrows:** yellow chevrons on the glowing boost pads.
- **Speed jumps:** red ramps at 2 points per lap. At speed above 70 you fly for up to about a second, rising over your shadow. No steering and no barrier damage while airborne, and rivals jump too.
- **Controls:** SPACE or joystick up to accelerate, `,` `.` to steer, N or joystick down to brake, M or fire for the weapon, H for half-rate rows.

## Tested

A whole cup was played automatically in the emulator: the autopilot drove, and a scripted SPACE press started it. All 4 races, cards and standings ran. The autopilot won every round with times of 1:06–1:12. That means the cup is forgiving for a good line; a human who scrapes walls will have real races. Rival speeds are simple numbers to tune.
