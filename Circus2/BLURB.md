# CIRCUS 2
### for the Dick Smith VZ200 / VZ300 — Vibed by BPM 2026

**Roll up, roll up!** The classic VZ seesaw-and-balloons game is back as a deluxe sequel.
You slide the seesaw, catch the tumbling clown on the high end and fire his partner into
the balloons. It's the same simple idea that made the original fun, now with an
unreasonable amount of circus around it.

Land the clown right on the tip of the plank for a **PERFECT!** launch that bounces off the
big-top roof. Chain your pops into combos up to x8. Keep a catch streak going, and flip
the seesaw to save a bad drop.

There are nine themed acts, each in its own colour scheme:

1. **Opening Night**
2. **Gifts Galore**
3. **Monkey Business** — a tightrope monkey lobbing custard pies
4. **Balloon Bonanza** (bonus round)
5. **Ring of Fire** — a flaming hoop
6. **Bombs Away** — exploding and steel balloons
7. **The Night Show** — bobbing rows
8. **Prize Pop** (bonus round)
9. **Grand Finale**

Then the curtain rises on an **ENCORE**, with everything faster.

Striped gift balloons drop seven power-ups: wide seesaw, slow motion, safety net, double
points, umbrella, fireworks and an extra life.

It all wraps up in:
- a big-top title screen with chasing marquee lights
- a two-voice circus march
- theatre-curtain transitions between acts
- bunting, barber-pole tent poles and chasing floor lights
- confetti and floating score pop-ups
- a full attract sequence with an AI demo
- high-score name entry

## Specifications

| | |
|---|---|
| **Machine** | Dick Smith VZ300 or VZ200, Z80A at 3.5 MHz |
| **Memory** | Needs RAM from $7800 to $F9FF, e.g. a BennVenn SD + 128K expansion. Will not run on an unexpanded machine |
| **Storage** | Loads from SD (BennVenn) as a binary .VZ |
| **File** | `CIRCUS2.VZ`, 23 KB, loads and autostarts at $8000 |
| **Display** | Genuine Mode 1 throughout (6847 CG2: 128×64, 4 colours). Both colour sets are used, with a different background colour per act |
| **Frame rate** | 25 fps, double-buffered, with dirty-span screen updates |
| **Sound** | Two-voice square-wave beeper music and sound effects (one voice on each speaker bit). Circus march on the title, the original Circus jingle at each act |
| **Controls** | Keyboard: Z/X or M/, move, SPACE/RETURN flip, P pause. Joystick 1: auto-detected |
| **Options** | Easy / Normal / Hard (5 / 4 / 3 lives, slower or faster balloons) and sound on/off on the title screen |
| **Content** | 9 acts (7 standard, 2 bonus) plus an endless Encore loop. 7 power-ups, 4 balloon types (normal, gift, bomb, steel) plus gold balloons in the bonus rounds. Combo, streak, row-clear, no-falls and extra-life rewards |
| **Attract mode** | Title, AI gameplay demo, How to Play, Goodies, Top Clowns, Coming Up |
| **High scores** | Top 5 with three-letter initials, kept until power-off (not saved to SD) |
| **Exit** | Reset or power-cycle |
| **Language** | 100% Z80 assembly (sjasmplus), with Python asset tools |

*Circus 2 is a fan-made sequel to the original VZ game Circus.*
