# CAPE FURY — design document

A one-on-one fighting game for the Microbee Premium Plus, native Z80.

VIBED BY BPM 2026 · Design v0.1, 12 November 2026 · Status: **design only, no code yet**

---

## 1. Pitch

Every seven years the light at Cape Fury goes out for one night, and the wreck coast holds the **Lantern Tournament**. Fighters climb from the beach to the lantern room, one bout at a time. Whoever beats the Keeper relights the lamp and holds the cape until the next dark.

CAPE FURY is a side-view, single-screen fighter in the Street Fighter II mould: best of three rounds, health bars, a round timer, and fights decided by distance and timing. Every attack shows its wind-up, has one clear moment of impact, and leaves a recovery the other player can punish. Directions and two buttons. Eight fighters and a boss.

Two rules shape everything below:

1. **A steady, readable fight beats more fighters or more animation.**
2. **Nothing about the keyboard, the redraw speed or the disk is assumed.** Four small test programs run on your machine first, and their numbers set the controls, the fighter size and the tick rate.

---

## 2. What is and isn't verified

No part of this game has run anywhere yet. The design rests on three kinds of information, kept apart on purpose.

**Published by Microbee Technology** (spec page and Quick Start Guide):

- Z80 at 3.375 MHz, plus a ColdFire that this game does not use.
- 2 MB RAM, of which 1 MB is shared space the Z80 side can reach.
- 32K PCG RAM, 2K colour RAM, 2K attribute RAM.
- Monochrome composite video and colour TTL video.
- SD card with floppy emulation in Z80 mode. `BEEMODE.CFG` on the card's FAT16 partition picks the mode and names the image for each drive. Modes 1 and 2 boot from an emulated drive A. Raw double-sided 80-track images must be named `.DS8`. File names are 8.3 only.

**Recorded in your earlier Microbee projects in this repo** (FRILLSEEKER, KABOOMERANG, THE LANTERN DEEP, the megademo). I have taken these from those notes, not re-measured them:

- 40 × 25 cells of 8 × 8 pixels (320 × 200) works on your Premium Plus. It needs the CRTC table **and** the dot clock select on port `09h`; the table alone gave four slanted pictures on your amber monitor.
- PCG is 16 banks of 128 glyphs, 2,048 in all. Attribute RAM picks a cell's bank. Port `1Ch` bit 7 enables it.
- Colour RAM is reached through port `08h` bit 6: paper in the high nibble, ink in the low.
- The CPU is held whenever it touches screen, attribute, colour or PCG RAM during a displayed line. In vertical blanking it runs freely. With 200 lines displayed, blanking is 113 lines, about 24,400 T-states.
- There is no usable frame interrupt. Timing comes from polling the 6545 status bit for vertical blanking.
- Expanded RAM is 32 blocks of 32K through port `50h`, one block mapped at `0000–7FFF`, block 0 fixed at `8000–EFFF`.
- Keyboard is read by the 6545 light-pen scan. Joystick is on PIO port A. Speaker is PIO port B bit 6, CPU-timed.
- FRILLSEEKER measured about 26,000 T to compose 22 sprite cells over scenery and 4,100 T to copy them to the PCG: roughly **1,400 T per cell**.
- Disks boot to `A>` with no shell, and you type the program name.

**Not known yet** (each has a test in section 9):

| Question | Why it matters | Test |
|---|---|---|
| Which keys register together, and which combinations produce phantom or dropped keys | Sets the default keys, whether A+B chords are safe, and whether two players can share the keyboard | KEYTEST |
| How many buttons your joystick reports on PIO A | Two attack buttons are the whole control scheme | KEYTEST |
| Time from key press to changed picture | The game's feel | LAGTEST |
| Redraw cost with two large fighters overlapping and attacking | Sets fighter size and tick rate | DRAWTEST |
| How overlapping fighters look on the amber monitor, and in real colour | You have seen colour only in an emulator so far | DRAWTEST gallery |
| Load speed from the emulated floppy, and whether writing a save file works | Sets how much loads before each match, and whether progress is saved | LOADTEST |
| That all 32 RAM blocks are free under the disk system this game boots from | Sets how many fighters stay cached | LOADTEST |

---

## 3. The fight

### Screen (40 × 25 cells)

| Rows | Use |
|---|---|
| 0–1 | Names, round-win lamps, health bars, two-digit timer in the centre |
| 2–7 | Scenery: sky, lighthouse, rocks. Fighters never reach it |
| 8–20 | The fight band. Kept almost empty behind the fighters |
| 21–23 | Floor and foreground |
| 24 | Message line: round calls, move names |

The floor line is the top of row 21, so a grounded fighter's feet are always on a cell boundary.

Your 4:3 screen shows 320 × 200 pixels as 1.2 times taller than wide. All art is drawn with that in mind: circles are drawn squashed, and figures are drawn a little short so they don't look stretched.

### Fighters on screen

- Standing frame 32 × 56 pixels (4 × 7 cells). Attack frames reach to 48 wide. Crouch frames are 40 tall.
- Limbs at least 3 pixels thick. No detail smaller than 2 pixels.
- Each attack is three pictures: wind-up, strike, and the wind-up again as recovery. About 36 pictures per fighter in total.

### Timing

- Game logic runs at a fixed **25 ticks a second** (one tick = two video fields). All move data is in ticks.
- Keys are sampled **every field**, at both blanking waits inside a tick, and presses are latched. A tap shorter than a tick still counts.
- Target from key press to changed picture: 3 fields (60 ms) or less.
- 50 ticks a second is not planned. By FRILLSEEKER's numbers, two fighters this size cannot be recomposed in one field.

### Rules

- Best of three rounds. 60-count timer. On time-out, more health wins. Equal health replays the round.
- 120 health each, one pixel of bar per point. Normal hits do 4–12, signature moves 10–16. A round takes about ten clean hits.
- **Blocking:** hold away from the opponent. Standing block stops high and jumping attacks. Down-and-away stops low attacks. Jump attacks must be blocked standing, sweeps crouching. On Easy, either block stops everything.
- Blocked normals do no damage and push the attacker back. Blocked signature moves do 2 chip damage, and chip cannot end a round.
- **Hit-stop:** a landed hit freezes both fighters for 2 ticks. The hit sound plays in that pause, so sound never takes time from the fight.
- **Whiff punishing:** an extended limb can be hit for the whole strike and recovery. Missing a heavy at the wrong range costs you.
- Sweeps and some signature moves knock down for 12 ticks. The fallen fighter cannot be hit until standing.
- Bodies cannot pass through each other on the ground. They push.
- No dizzies and no long combos. A light attack into a signature move is the only link. Throws come in the full game as the answer to constant blocking.

---

## 4. Controls

| Input | Standing | Crouching (hold down) | Jumping |
|---|---|---|---|
| **A** (light) | Jab: fast, short | Low jab | Jump punch |
| **B** (heavy) | Big hit: slow, long | Sweep: low, knocks down | Jump kick |
| **A+B** | Signature move 1 | Signature move 2 (down + A+B) | — |

- Left and right walk. Up jumps straight, up-left and up-right jump that way. A jump is a fixed arc.
- Signature moves are both buttons together, with or without down. The two presses may land up to 3 ticks apart. KEYTEST measures your real gap and sets the window.
- Fighters turn to face each other automatically.

### Keys are chosen after KEYTEST, not before

The Microbee keyboard is a switch matrix read one key at a time through the 6545. I expect three held keys at the corners of a rectangle in that matrix to produce a fourth, phantom key, but I have not seen this confirmed on a Premium Plus. A fighter needs up to four keys held by one player (two directions and two buttons) and eight with two players.

Candidates to test, in order of preference:

| Use | Keys |
|---|---|
| One player | `W A S D` to move, `K` light, `L` heavy |
| Player 2 on a shared keyboard | `I J K L` to move, `;` `:` for buttons, with player 1's buttons moved to `F G` |
| If A+B chords fail on the best layout | A third key for signature moves |

Rules for picking the defaults from the results:

1. Every combination one player can hold must register cleanly, with no phantom and no dropped key.
2. If no layout passes with A+B plus a diagonal, the third signature key becomes standard.
3. Keys can be redefined in the options screen, and the choice is saved if LOADTEST shows saving works.

### Two players

1. **Keyboard against joystick** is the planned versus mode. It needs no shared matrix.
2. **Shared keyboard** is offered only if KEYTEST passes every eight-key case for both layouts. If it fails, it is left out.
3. If the joystick reports one button, joystick play gets heavy attacks on a held-button press and versus waits for a two-button stick.

---

## 5. Roster

### First playable pair

**Wren Hallett — the wickie's apprentice. Fast, close-range.**
Slim figure in a sou'wester and short oilskin. Quick walk, long low jump, short arms. Wins by getting inside the boathook's reach and staying there.

**Harrow Tate — hard-hat salvage diver. Slow, controls space.**
Round brass helmet, bulky suit, weighted boots, a boathook. Slow walk, short heavy jump. Keeps people out with the hook and makes them jump with a floor shockwave.

Frame data in ticks (startup / active / recovery). Reach is in pixels from the front of the body.

| Wren | Timing | Damage | Reach | Notes |
|---|---|---|---|---|
| Standing A, jab | 2 / 1 / 2 | 5 | 14 | Safe when blocked |
| Standing B, hook kick | 4 / 2 / 5 | 10 | 20 | |
| Crouching A | 2 / 1 / 3 | 4 | 14 | |
| Crouching B, sweep | 4 / 2 / 7 | 9 | 22 | Low, knocks down |
| Jumping A / B | 2 / 3 | 6 / 10 | 12 / 18 | Block standing |
| **Stair Run** (A+B) | 3 / 5 / 8 | 13 | travels 44 | Hopping kick that passes over low attacks and the shockwave. Punishable when blocked |
| **Trim the Wick** (down + A+B) | 2 / 5 / 12 | 16 | 12, upward | Rising strike that beats jump-ins. A miss leaves her wide open |

Walk 3 px/tick forward, 2 back. Jump 14 ticks, 40 px high.

| Harrow | Timing | Damage | Reach | Notes |
|---|---|---|---|---|
| Standing A, hook jab | 3 / 1 / 3 | 6 | 26 | |
| Standing B, boathook thrust | 6 / 2 / 7 | 12 | 40 | The longest normal in the game |
| Crouching A | 3 / 1 / 4 | 5 | 24 | |
| Crouching B, boot sweep | 6 / 2 / 9 | 10 | 34 | Low, knocks down |
| Jumping A / B | 3 / 5 | 7 / 12 | 18 / 24 | Block standing |
| **Lead Boots** (A+B) | 6 / travels / 9 | 10 | up to 160 | Stomp sends a ripple along the floor at 4 px/tick. Jump it or block it crouching. One on screen at a time |
| **The Gaff** (down + A+B) | 4 / 3 / 11 | 15 | 36, diagonal up | Catches jumpers and knocks them down. A miss leaves him open |

Walk 1.5 px/tick forward, 1 back. Jump 12 ticks, 28 px high.

How the match-up plays: Harrow's ripple forces a jump and The Gaff catches it. Wren's answers are to walk and block until she is close enough to punish the stomp's recovery, or to Stair Run over the ripple. Once inside, her jab is faster than anything Harrow owns and his only way out is to block and push her off.

### Full roster

| Fighter | Style | Signature idea |
|---|---|---|
| Wren Hallett, wickie's apprentice | Fast, close | Stair Run, Trim the Wick |
| Harrow Tate, salvage diver | Slow, long reach | Lead Boots, The Gaff |
| Dr Isolde Finch, ornithologist | Keep-away | Sends a shearwater across the screen as a slow projectile, then moves behind it |
| "Tuck" Baptiste, whaleboat steersman | Grappler | A grab that beats blocking, and an armoured shoulder charge |
| Kit Marlin, cray fisher | Trapper | Drops a cray pot on the floor that snaps at whoever steps on it |
| Signalman Sue Abara | Mid-range feints | Flag strikes that can be cancelled into a block |
| Lantern Jack, wrecker | Trickster | Throws a false light, then swaps places with it |
| Mirren, the seal-wife | Low and evasive | A slide under high attacks and a rising tail strike |
| **The Keeper** (boss) | Slow, huge reach | The lamp flash: a full-screen strike with a long, loud wind-up that must be blocked |

Each new fighter is a disk file, so the roster grows without touching the engine.

### Telling them apart

Every fighter has a different outline at a glance: sou'wester, round helmet, long coat, bare shoulders, flags. One fighter in each first-playable pairing is drawn **solid** and the other **light with a heavy outline**, like black and white chess pieces. In a mirror match, player 2's clothing areas are refilled with a stripe pattern when the fighter loads.

---

## 6. Single-player progression: The Climb

Pick a fighter and fight up the cape. Seven bouts, each in its own arena.

| Bout | Arena | Opponent |
|---|---|---|
| 1 | Wreck Beach | Drawn from the roster |
| 2 | The Jetty | Drawn from the roster |
| 3 | The Tryworks | Drawn from the roster |
| 4 | Sea Cave | Your rival, fixed per fighter, with a line of story before the bout |
| 5 | Cliff Tramway | Drawn from the roster |
| 6 | The Gallery, outside the lamp room | Lantern Jack, or Mirren if you are playing Jack |
| 7 | The Lantern Room | The Keeper |

- The CPU gets a little sharper each bout.
- **Unlimited continues.** Losing a bout restarts that bout, and after two losses in a row the CPU drops one notch for the rematch.
- Easy, Normal and Hard. Easy also turns on the block-anything rule.
- The furthest bout reached per fighter is saved to disk, if LOADTEST shows saving works. If not, a short password does the same job.
- Beating the Keeper shows that fighter's ending picture and relights the lamp on the title screen.

Other modes: Versus, and Practice with hit boxes drawn and the frame data shown as moves are used.

---

## 7. Graphics and drawing

### PCG budget (2,048 glyphs)

| Banks | Glyphs | Use |
|---|---|---|
| 0 | 128 | Font, health bar pieces, timer digits, lamps |
| 1–6 | 768 | The current arena |
| 7 | 128 | Moving scenery, the floor ripple, hit sparks |
| 8–9 | 256 | Portraits, round banners |
| 10–11 | 256 | Player 1's glyph pools (two, taking turns) |
| 12–13 | 256 | Player 2's glyph pools |
| 14 | 128 | Pools for cells both fighters share |
| 15 | 128 | Spare |

### Drawing only what changed

The arena is drawn once. After that, only cells a fighter or an effect touches are written.

- For each cell a fighter covers, a private glyph is built in ordinary RAM and the cell is pointed at it. The actual screen change is a short list written in vertical blanking, three bytes a cell. This is FRILLSEEKER's method.
- **A fighter that has not changed is not redrawn.** If pose, position and overlap are the same as last tick, nothing is composed. Attacks stand still, so each of their three pictures is composed once and held.
- **The fight band is kept nearly empty.** Where the cell behind a fighter is blank, the pre-shifted picture is copied straight in with no masking. Scenery that does cross the band is limited to a few marked cells per arena, and only those take the slower masked path.
- Fighters move in 2-pixel steps, so each picture is stored at four alignments for each facing.
- Sparks, the ripple and projectiles are ready-made glyphs. A spark replaces its cell for two ticks. The ripple is floor cells swapping glyphs, which costs almost nothing.
- The health bar changes one or two glyphs per hit. The timer changes once a second.

### When fighters overlap

A cell has one ink colour and one paper colour, so two fighters in one cell become one shape unless the art prevents it. Four measures, all tried in the DRAWTEST gallery before any fighter art is finished:

1. Bodies push, so on the ground only limbs cross the other fighter. Full overlap happens only during jumps.
2. The fighter in front is cut out of the one behind with a mask one pixel wider than the picture, leaving a dark keyline around it.
3. Solid against outlined figures, as above.
4. Shared cells take a neutral bright ink in colour mode, so neither fighter's colour floods the other.

The fighter in front is the one whose attack is active, so the striking limb is always visible. The order never changes in the middle of a move.

### Colour and monochrome

A startup screen offers Colour or Monochrome, as in your other Microbee games. Monochrome art uses ink on black only. Colour identifies the fighters and dresses the arena, but nothing in the game depends on it: health is bar length, round wins are lit lamps, and a blocked hit has a different spark shape from a clean one.

### Frame budget

One field is 67,500 T. One tick is two fields, 135,000 T. These are planning figures until DRAWTEST replaces them.

| Per tick, worst case | T-states |
|---|---|
| Key scan, twice | 6,000 |
| Two fighters: state, boxes, hits, pushing | 10,000 |
| CPU opponent (runs every second tick) | 3,000 |
| Composing 60 cells at FRILLSEEKER's masked rate | 84,000 |
| Screen list in blanking, 60 cells | 6,000 |
| Health bar, timer, effects | 2,000 |
| Lost to video holds | 8,000 |
| **Total** | **about 119,000 of 135,000** |

That worst case is both fighters moving, overlapped, in their widest pictures, every cell on the slow path. With the empty band and unchanged-fighter rules, the usual tick should be well under half of that. The time left over in each tick goes to sound.

If DRAWTEST says the worst case does not fit, the steps are, in this order: fighters 48 pixels tall, then 4-pixel walking steps, then no scenery in the band at all. The tick rate stays at 25.

### Memory and disk

- A fighter on disk is about 36 pictures stored once, trimmed, facing right: roughly 16–20K.
- On loading, each picture is expanded into four alignments and two facings with masks: about 7 RAM blocks per fighter. Two fighters use 14 of the 32 blocks. The arena takes one, the program and sound stay in block 0.
- Expanded fighters stay in RAM while there is room, so a rematch or the next bout loads only what is new.
- The disk is read only on the versus screen before a match and on menus. Never during a round.

Distribution is one raw image, `FURY.DS8`. Copy it to the SD card, name it as drive A in `BEEMODE.CFG` (mode 1 or 2), boot to `A>`, type `FURY`.

| File | Contents |
|---|---|
| `FURY.COM` | Loader and engine |
| `WREN.FTR`, `HARROW.FTR` | Fighter pictures, boxes, move tables, CPU tables |
| `JETTY.ARN` | Arena glyphs, cell map, colours, monochrome variant |
| `TITLE.PIC` | Title screen |
| `SAVE.DAT` | Keys, options, progress |

### Sound

One speaker bit and no interrupt. Sound is made only in the time a tick has left before its second blanking, and in hit-stop. In a fight: hit, heavy hit, block, whiff, jump landing, knockdown, the round bell, the timer's last ten counts. Music plays on the title, the versus screen and between rounds.

### CPU opponent

- Every few ticks it looks at three things: distance (far, mid, close), what the player is doing (idle, winding up, recovering, in the air, down), and its own state. It picks from a weighted table for that situation. Each fighter has its own tables.
- It sees the player through a delay: 10 ticks on Easy, 6 on Normal, 3 on Hard. It never reads the keys.
- It punishes a missed attack only when it has a move whose startup is shorter than the recovery left, and then only some of the time: about one in four on Easy, three in four on Hard.
- On Easy it walks into range and misses heavies on purpose, so there are openings to learn from.

---

## 8. First playable build

**Contents:** Wren and Harrow, The Jetty, one full best-of-three match against the CPU. Either fighter selectable, mirror matches allowed.

| Stage | Built | Done when |
|---|---|---|
| 0 | Test disk `FURYTEST.DS8` with the four programs in section 9 | You have run them and sent the result screens |
| 1 | Arena, both fighters walking, jumping, crouching, pushing | DRAWTEST numbers hold in the real engine |
| 2 | Attacks, boxes, blocking, hit-stop, health, knockdown | Every normal can be whiff-punished by the other fighter |
| 3 | Round flow: "ROUND 1", "FIGHT", timer, KO, time-out, best of three, win and loss poses | A match can be played start to finish by two humans |
| 4 | CPU opponent at three levels | The CPU finishes matches without getting stuck, and you can beat Easy |
| 5 | Signature moves, sound, title, fighter select, Colour/Monochrome choice, key options | All of the above from one boot |
| 6 | `FURY.DS8` release with README | It runs from your SD card on the amber monitor |

Left out of the first playable: throws, the other fighters and arenas, The Climb, endings, saving progress.

---

## 9. Testing on the real machine

All four programs are on one disk, run from `A>`, return to `A>`, and end on a results screen made to be photographed. Each is also run in the emulator first, but the emulator cannot answer the keyboard question and may not model video holds exactly, so your machine's numbers win.

### KEYTEST: what registers together

- Shows all 64 key positions as a grid and lights every one the scan reports, with its matrix code. Shows the raw PIO A bits for the joystick beside it.
- A guided run asks you to hold each candidate set: one player's four keys in every useful combination (diagonal plus A, plus B, plus both), then both players' sets together.
- For each set it records the keys seen. An extra key is a phantom. A missing key is a drop.
- It also times one full scan of the game's keys, and measures the gap between your two fingers on an A+B press over twenty tries.
- Result: a pass/fail table per layout. That table chooses the defaults and decides the shared-keyboard question.

### LAGTEST: input response

1. **Baseline.** The field a key is first seen, a block of cells inverts and the speaker clicks. Film the keyboard and screen together with a phone at 240 frames a second and count frames from the key bottoming out to the block changing. That figure is the keyboard, the scan and the monitor, with no game in the way. Do it on the amber monitor, and on the VGA converter if you use one, since a converter can add delay of its own.
2. **Pipeline.** The same press goes through the real loop: sample, logic, compose a fighter-sized picture, list, flip. The program counts fields from latch to flip itself and shows least, most and average over fifty presses. Target: 3 fields or less.
3. **Short taps.** It reports the shortest press it caught and any press it saw on one field but not the next, to confirm that sampling every field loses nothing.

### DRAWTEST: redraw speed

Scripted, with no input, so every run is identical. Placeholder fighters at full size.

| Scene | What happens |
|---|---|
| 1 | Both standing still |
| 2 | One walks |
| 3 | Both walk towards each other |
| 4 | Both jump at once |
| 5 | Pushing switched off: they walk through each other, with the keyline |
| 6 | Overlapped, both in their widest strike pictures, with a spark and the floor ripple |
| 7 | Scene 6 with scenery behind every cell, forcing the slow path |

For each scene the results screen gives:

- Fields per frame: least, most, average.
- Spare time per tick, from counting turns of a calibrated idle loop before blanking arrives.
- Cells composed and cells listed.
- Whether the screen list finished inside blanking. If the blanking bit has dropped by the time the list ends, that frame is counted as a tear.

**Pass:** scenes 1–6 never take more than two fields, with at least 8,000 T spare in scene 6, and no tears. Scene 7 may fail; it only tells us how much scenery the band can afford.

**The overlap gallery** follows: still pictures of the overlap cases, lettered. Keyline against none, solid against outlined, shared cells in neutral ink against the front fighter's ink, mirror match with and without stripes. Look at them on the amber monitor, and in colour if you can, and tell me which letters read best.

### LOADTEST: disk and memory

- Times loading a 16K and a 64K file from the emulated floppy.
- Writes a small file, reads it back and compares it.
- Writes a pattern to each of the 32 RAM blocks and checks them all after a disk read, to confirm nothing in the disk system uses them.

### Order

KEYTEST first, because it decides the controls. DRAWTEST second, because it decides the size of every picture that will be drawn. Fighter art starts only after both.
