# RED DUST RUMBLE — design document

A one-on-one fighting game for the Dick Smith VZ300 with the BennVenn SD Loader and 128K RAM expansion.

VIBED BY BPM 2026 · Design v0.1, 12 November 2026 · Status: **design only, no code yet**

---

## 1. Pitch

It's show week, and Sable's Travelling Boxing Tent has rolled into town. Anyone who can last three rounds with a troupe fighter wins a purse. Anyone who beats the whole troupe gets a shot at the Ringmaster and the deed to the tent.

RED DUST RUMBLE is a side-view, single-screen fighter in the Street Fighter II mould: best-of-three rounds, health bars, a round timer, and fights decided by spacing rather than button speed. Every attack has a visible wind-up and a recovery you can punish. Two buttons, one stick, six fighters, one boss.

The design rule for everything below: **a steady, readable fight beats a bigger roster or more animation.**

---

## 2. What is and isn't verified

Nothing in this document has been run on hardware yet. It is built from three kinds of information, and they are kept apart on purpose.

**Measured on your VZ300 in earlier projects** (treated as fact):

- Mapper is on port `$37`. Bit 0 = DOS area is SRAM; bit 1 = selects the 10K bank at `$4000-$67FF`; values 1 and 3 hold separate data. Bit 2 is modelled as swapping the 18K at `$B800-$FFFF`, but your tests of it disagree with each other (RASTEST said it switches, BIX said `$37=5` overwrote the home bank).
- VZDOS 2.31 runs from SRAM at `$4000`; file calls at `$5F00/$5F03/$5F09` work; the DOS needs `$FA00-$FFFF` left alone.
- The DOS call recipe that works: sector buffer at `$F800`, a 2.5K stack, interrupts on during the call, `DI` after it, nothing of ours below `$7AE9`.
- A `.VZ` loading low at `$8000` with no mapper writes during load is safe. One that loaded up to `$F9FF` and switched to bank 1 while unpacking reset the machine.
- IM2 frame interrupts work. Field = 70,630 T-states, 312 lines, 50 fields a second. Writing to video RAM during the picture costs no extra time and makes no snow.
- 32 SD sectors (16K) read in 20 fields.
- Joystick 1: directions on `$2C`, its two buttons on `$2E` and `$2D`. Joystick 2: buttons on `$2B` and `$27`, left/right on `$29`; **down is intermittent**.
- Exit to the SD shell works by writing `$37=0` and jumping to the ROM start. There is no reset button, so every test program must exit this way.
- Screen is 4:3, so mode 1 pixels are 1.5 times taller than wide.

**From the BennVenn manual** (not yet reconciled with the above):

- The manual puts the RAM-map switch on port 55 (`$37`) and the bank bits on port 58 (`$3A`). Your machine responds to the bank bits on `$37`. The game follows your machine, and BANKTEST (section 9) re-checks it.
- Port 74 (`$4A`) switches between the SNES pad interface and the original VZ joysticks, and the manual says the SNES interface is on by default. Your joystick already works in VZ-DECK without touching this port, so the game will not write to it unless PADTEST shows directions missing.
- The manual does not document DOS entry points, a file size limit, or loading from machine code.

Note: the vz200.org copy of the manual blocks automated access, so I read the same-titled "BennVenn SD Card Reader 2" manual on BennVenn's own site. If your copy differs, the tests in section 9 will show it.

**Estimates** (to be replaced by measurements): every T-state cost and byte count in sections 6 and 7.

---

## 3. The fight

### Screen (mode 1, 128x64, four colours)

| Rows | Use |
|---|---|
| 0-7 | HUD: P1 health bar (48 px) on the left, P2 on the right, two-digit timer in the middle, round-win pips under each bar |
| 8-55 | Arena. Fighters stand on row 55 |
| 56-63 | Floor strip |

- Health bars drain toward the centre. A bar turns from yellow to red below one quarter.
- Background is flat green with a low-detail backdrop confined to rows 8-30 (tent poles, bunting, crowd as a single dotted band). Nothing in the backdrop uses blue or red.
- **Player 1's fighter is always solid blue. Player 2's is always solid red.** Yellow is the shared highlight colour (gloves, hat, whip). Colour is identity, so two overlapping fighters, or a mirror match, stay readable.

### Fighters on screen

- Standard frame 24x32 pixels (6 bytes by 32 rows). On a 4:3 screen that shows as a 1:2 figure.
- Attack frames may extend to 32 wide. Crouch frames are 20 tall. Art is drawn chunky: limbs at least 2 pixels thick, no single-pixel detail.
- Poses are few and strong. Each attack is three pictures: wind-up, strike, and the wind-up again as recovery.

### Timing

- Game logic runs at a fixed **25 ticks a second** (one tick = two video fields). All move data is written in ticks.
- The joystick is read **every field** inside the frame interrupt and presses are latched, so a quick tap is never lost between ticks.
- If DRAWTEST shows the worst case fits in one field with room to spare, the tick can move to 50 a second and the tables are doubled. That is decided by measurement, not hope.

### Rules

- Best of three rounds. 60-count timer. On time-out, more health wins; equal health means the round counts for nobody and is fought again.
- 96 health each. Normal hits do 4-12, specials 12-16. A round takes roughly 8-12 clean hits, so one mistake never ends it.
- **Blocking:** hold away from the opponent. Standing block stops high and jumping attacks. Crouching block (down-away) stops low attacks. Jumping attacks must be blocked standing; sweeps must be blocked crouching.
- Blocked normal attacks do no damage. Blocked specials do 2 chip damage, and chip cannot finish a round.
- A landed hit freezes both fighters for 2 ticks (hit-stop). This sells the impact and is also where the hit sound plays, so sound never steals time from the fight.
- Knockdowns (sweeps and some specials) put the victim on the floor for 12 ticks, invulnerable until standing.
- No dizzies, no combos beyond a light into a special, no throws in the first playable. Throws are added in the full game as the answer to an opponent who only blocks.

---

## 4. Controls

One direction pad and two buttons per player.

| Input | Standing | Crouching (hold down) | Jumping |
|---|---|---|---|
| **A** (light) | Jab: fast, short | Low jab | Jump punch |
| **B** (heavy) | Big hit: slow, long | Sweep: hits low, knocks down | Jump kick |
| **A+B** | Signature move 1 | Signature move 2 (down + A+B) | — |

- Left/right walk. Up jumps straight; up-left and up-right jump that way. Jumps are fixed arcs: once you leave the ground you are committed.
- Away = block. Down-away = crouch block.
- **Signature moves are A+B pressed together**, with or without down. No quarter-circles. The two presses may land up to 3 ticks apart; PADTEST measures your real gap and sets that window.
- Fighters turn to face each other automatically when they cross.

**Keyboard fallback** (pending KEYTEST for ghosting): P1 `W A S D` + `F G`; P2 `I J K L` + `;` `:`.

**Local versus** depends on PADTEST:

1. Default: joystick 1 against keyboard. Always available.
2. Two joysticks: only offered if joystick 2 passes the hold-down test. Crouching, low blocks and both down-specials need a reliable down, and yours is currently intermittent.
3. Two players on one keyboard: only if KEYTEST shows no ghosting with six keys held.

---

## 5. Roster

### First playable pair

**"Flick" Finnegan — gun shearer. Fast, close-range.**
Quick walk, low short jump, short arms. Wins by getting inside and staying there.

**Dusty Marlowe — drover. Slow, long reach.**
Slow walk, high floaty jump, and a stockwhip that hits from a third of the screen away but leaves her open if it misses.

Frame data, in ticks (startup / active / recovery). Reach is in pixels from the front of the body.

| Flick | Timing | Damage | Reach | Notes |
|---|---|---|---|---|
| Standing A | 2 / 1 / 2 | 5 | 14 | Safe when blocked |
| Standing B | 4 / 2 / 5 | 10 | 18 | |
| Crouching A | 2 / 1 / 3 | 4 | 14 | |
| Crouching B | 4 / 2 / 7 | 9 | 20 | Low, knocks down |
| Jumping A / B | 2 / 3 | 6 / 10 | 12 / 16 | Block standing |
| **Blade Run** (A+B) | 4 / 6 / 8 | 14 | travels 40 | Dashing punch. Blocked = punishable |
| **Tin Roof** (down + A+B) | 2 / 5 / 12 | 16 | 12, upward | Rising uppercut, beats jump-ins. Miss = wide open |

Walk 2 px/tick forward, 1.5 back. Jump lasts 14 ticks.

| Dusty | Timing | Damage | Reach | Notes |
|---|---|---|---|---|
| Standing A | 3 / 1 / 3 | 6 | 20 | |
| Standing B | 6 / 2 / 7 | 12 | 30 | |
| Crouching A | 3 / 1 / 4 | 5 | 20 | |
| Crouching B | 6 / 2 / 9 | 10 | 32 | Low, knocks down |
| Jumping A / B | 3 / 5 | 7 / 11 | 16 / 22 | Block standing |
| **Whip Crack** (A+B) | 7 / 2 / 9 | 14 | 34 to 56 only | Hits at the tip. Misses anyone closer than 34 |
| **Ankle Snare** (down + A+B) | 8 / 2 / 11 | 12 | 30 to 50 | Low whip, knocks down |

Walk 1 px/tick. Jump lasts 18 ticks.

Hit-stun is 5 ticks (light) or 8 (heavy); block-stun 3 or 5; pushback 4 or 8 pixels. So a blocked Blade Run leaves Flick recovering for 8 ticks against 5 of block-stun: a 3-tick gap, enough for a jab but not a heavy. Those gaps are the game.

**How the match-up plays:** Dusty owns the range from 30 to 56 pixels. Flick has to walk and block through it or jump over it, and Dusty's standing B and a well-timed Ankle Snare are there to stop him. Once Flick is inside 20 pixels the whip is useless and his jabs come out a tick faster than anything she has.

### Full roster

| Fighter | Trade | Style |
|---|---|---|
| Flick Finnegan | Shearer | Rushdown |
| Dusty Marlowe | Drover | Long-range poking |
| Bruno "The Kiln" Bianchi | Bricklayer | Slow heavyweight. One armoured charge that absorbs a single hit |
| Skink | Tent acrobat | Aerial. Fast high jump, dive kick, weak on the ground |
| Opal Annie | Opal miner | Trapper. Rolls a slow "fizzer" along the floor that must be jumped or blocked low |
| Professor Volt | Sideshow electric man | Counter-fighter. A stance that punishes whoever hits it |
| **Mr Sable** (boss) | Ringmaster | Cane for reach, coat-tail sweep, and one move borrowed from each troupe fighter |

### Single-player: The Circuit

- Pick a fighter. Fight the other five troupe members across five show towns, then a mirror match against your own "understudy", then Mr Sable in the main tent at night. Seven fights.
- Arenas: Showground Tent, Shearing Shed, Stockyard, Opal Field, Pub Verandah, Main Tent (night). One backdrop screen each.
- Between fights 3 and 4: the High Striker bonus stage (time a button press to ring the bell) for a small health bonus in the next fight.
- **Forgiving by design.** Three difficulty settings, Easy first in the menu. Unlimited continues, and you re-fight only the opponent who beat you. After each continue the CPU reacts one tick slower, down to a floor.
- One ending screen per fighter. Beating Sable without a continue unlocks him in versus.

### The CPU opponent

- A table-driven opponent, not a mind-reader. Each tick it looks at distance (close / mid / far) and what you are doing (idle, winding up, recovering, airborne, down), then picks from a weighted list.
- It only "sees" what you did some ticks ago: 8 on Easy, 5 on Normal, 3 on Hard.
- Each fighter's CPU has habits you can learn. CPU Flick throws Blade Run from mid-range too often; block it and hit back. CPU Dusty cracks the whip whenever you stand at range; jump it or walk in behind a block.
- It punishes obvious whiffs (a missed Tin Roof) on Normal and Hard, and only sometimes on Easy.

---

## 6. Memory plan

The match engine and all match state sit in RAM that is never banked. Art lives in the banked area. The SD card is touched only between screens.

| Address | Contents | Banked? |
|---|---|---|
| `$7000-$77FF` | Video RAM (mode 1) | No |
| `$7800-$7AE8` | System area. Left untouched so the DOS keeps working | No |
| `$8000-$B7FF` | Engine: code, move tables, CPU tables, match state, IM2 table and handler, stack (14K) | No |
| `$B800-$BFFF` | Clean copy of the current arena backdrop (2K) | No (bit 2 never set) |
| `$C000-$C7FF` | Shadow screen the fighters are composed into (2K) | No |
| `$C800-$F7FF` | HUD font, portraits, sound data, spare (12K) | No |
| `$F800-$FFFF` | Reserved: DOS sector buffer and DOS workspace | No |
| `$4000-$67FF` with `$37=1` | VZDOS, kept intact | Bank 0 |
| `$4000-$67FF` with `$37=3` | **Fighter frames.** P1's fighter `$4000-$53FF`, P2's `$5400-$67FF` (5K each) | Bank 1 |

- During a round the mapper stays at `$37=3` and is never touched. Both fighters' frames are visible at once, so drawing never switches banks.
- To load from SD: stop the round logic, set `$37=1`, call the DOS using the known-good recipe, `DI`, copy the loaded data from main RAM into bank 1 with `$37=3`. Loads happen at the title, after character select (behind the "VS" screen), and between fights.
- The 18K behind bit 2 is **not used**. Your tests of it conflict, and the game doesn't need it. BANKTEST includes an optional probe in case a later version wants it for more arenas.

**Fighter data.** About 24 frames each: 2 idle, 2 walk, crouch, jump, 2 blocks, 2 per standing attack, 1-2 per crouching attack, 2 jump attacks, hit, 2 knockdown, 2 per special, win pose.

- Frames are stored once, facing right, as plain 2-bit pixels with colour 0 as "see-through". No stored masks and no stored mirror copies.
- A 256-byte table turns each byte into its mask; another mirrors it for facing left. That halves the art twice over: roughly 5K a fighter instead of 20K.
- The blue/red recolour is done once when the fighter is copied into bank 1, so it costs nothing during the fight.
- The art tool refuses to build a fighter over 5,120 bytes.

**Files on the SD card (full game):** `RUMBLE.VZ` (engine, loads at `$8000`, stays under `$B800`) and `RUMBLE.DAT` (fighters, arenas, portraits, with a small index at the front). At the measured read speed a 5K fighter is about 7 fields, and a whole VS-screen load is well under a second.

---

## 7. Drawing and sound

**Drawing, per tick:**

1. For each fighter, copy the clean backdrop over its old box in the shadow screen.
2. Draw both fighters into the shadow screen. The fighter who is attacking is drawn last, so the strike is always on top.
3. Wait for the frame interrupt, then copy only the changed boxes to video RAM while the beam is in the border.

Nothing is ever erased on the visible screen, so there is no flicker, and the copy is short enough to finish before the picture starts.

Estimated worst case (both fighters in 32-wide frames): about 11,000 T to restore, 35,000 T to draw, 8,000 T to copy, 8,000 T for logic and CPU: around 62,000 T against a 141,000 T tick. That is under half the budget, and it is an estimate until DRAWTEST says otherwise.

**Sound** (one-bit speaker, effects only during a round):

- Hit: short noise thud, lower and longer for heavy hits. Plays inside the 2-tick hit-stop.
- Block: one bright click.
- Knockout: a falling sweep during the slow-down as the loser drops.
- Round start and end: a two-strike ring bell, played while "ROUND 1" or "K.O." is on screen and the fight is paused.
- No whiff sounds. Silence on a miss makes the hits land harder.
- Title tune: gritty, separate notes, not screechy. In-fight music is left out of the first playable so the timing tests are clean; a slow, sparse "dink… dink-dink" pulse between ticks can be added afterwards.

---

## 8. First playable build

**Scope:** Flick and Dusty, the Showground Tent, one complete best-of-three match against the CPU. Either fighter selectable. A single `RUMBLE.VZ` with both fighters built in (copied into bank 1 at start-up), so the first playable does not depend on the SD loader at all.

**In:** title screen with fighter pick and difficulty; round intro; health bars, timer, win pips; walking, jumping, crouching, both blocks; all six normals and both signature moves for each fighter; hit-stop, knockdown, K.O., time-out; CPU opponent with three difficulties; win/lose screen; rematch or quit to the SD shell; joystick 1 or keyboard, detected automatically.

**Out for now:** versus mode, throws, other fighters and arenas, The Circuit, music, `RUMBLE.DAT`.

**Steps, each one a file you can run:**

| Build | What it proves |
|---|---|
| Test programs (section 9) | The hardware assumptions |
| 0.1 | One fighter (coloured blocks, not art) walks, jumps, crouches on the real arena layout with the HUD drawn |
| 0.2 | Two block fighters, attacks with wind-up and recovery, hits, blocks, health bars. Second fighter on the keyboard |
| 0.3 | Real art for Flick and Dusty, signature moves, hit-stop, sound |
| 0.4 | CPU opponent, rounds, timer, K.O., win screen |
| 0.5 | **First playable.** Tuning pass on your machine: frame data, CPU reaction times, damage |

Fighting with coloured blocks in 0.2 is deliberate. If the spacing game is fun with rectangles, the art can only improve it. If it isn't, no art will save it and nothing has been wasted.

---

## 9. Testing on the real VZ300 before expanding

Four small programs, run in this order, before any game code depends on them. Each shows one results screen laid out to be photographed, and each exits to the SD shell on a key press.

### PADTEST — what the controls really do

- Live raw values of ports `$2C $2E $2D $2B $27 $29 $2A $25` and the keyboard rows, beside the decoded stick and buttons for each player.
- **Hold test:** hold each direction for 10 seconds; it counts every field where the direction dropped out. This settles whether joystick 2 can be used for versus.
- **Diagonals:** down-away and up-toward must both read, or crouch-blocking and angled jumps don't work.
- **A+B gap:** press both buttons together 20 times; it reports the gap in fields each time. The special-move window is set from your worst honest attempt plus one.
- **KEYTEST page:** hold the six-key combinations two keyboard players would use and report any phantom keys.
- Does not write to port 74 unless you choose that option from its menu.

### LAGTEST — input response

- **Click test:** the speaker clicks and the border colour flips inside the frame interrupt the moment a button reads pressed. This is the fastest the machine can possibly respond, so you learn what "instant" feels like on your screen and stick.
- **Tick test:** the same, but responding on the 25-a-second game tick with a block fighter punching. If this feels worse than the click test, the tick is too slow and the 50-a-second option becomes the priority.
- **Mark test:** a bar sweeps across the screen; press as it crosses the mark, 20 times. It reports your average error and spread in fields, once with latched interrupt reading and once with reading only on the tick. The latched version should show a tighter spread; if it doesn't, the latch isn't working.
- Run it on the screen you will actually play on. A modern TV can add more delay than the whole VZ.

### DRAWTEST — redraw speed

- Two worst-case block fighters driven by a script, using the real draw routines, shadow screen and border copy.
- Scenes: far apart; fully overlapped; both in 32-wide frames; both jumping; one mirrored; both mirrored.
- For each scene it reports T-states per tick (counted from the interrupt, using the measured 70,630 T field) and the worst tick seen in 30 seconds.
- **Tear check:** the fighters are vertical stripes sliding sideways. Any stair-step or shear in the stripes means the border copy is overrunning into the picture.
- **Pass:** worst case no more than 113,000 T (20% spare on a two-field tick), and no tearing. Under 56,000 T means 50 ticks a second is on the table.
- **If it fails,** in this order: shrink the standard frame to 20x28; copy only the rows that changed; drop the left-facing table in favour of stored mirror frames for the six most common poses.

### BANKTEST — the memory plan

- Fills bank 1 (`$37=3`) with a pattern while the frame interrupt runs, then checksums it every second for a minute.
- Switches `$37` between 3 and 1 a thousand times, with a DOS directory call on every tenth switch, and re-checks both the pattern and that the DOS still answers.
- Confirms the interrupt keeps counting through all of it.
- Optional page: probes bit 2 from code below `$B800` and reports whether `$B800-$FFFF` really holds a second copy. Informational only.

### What happens with the results

- All four pass: build 0.1 goes ahead as designed.
- Anything fails: the design changes before the code does, and this document is updated with the measured numbers.
- Before every later expansion (versus, `RUMBLE.DAT`, each new fighter), DRAWTEST is re-run with that fighter's largest frames, and a LOADTEST times the real file from your card.

Every build is also run in the project's test emulator first, but the emulator only catches logic bugs. Control feel and redraw timing are signed off on your machine.

---

## 10. After the first playable

1. Local versus (joystick against keyboard first).
2. Throws, then a balance pass.
3. `RUMBLE.DAT` and SD loading; second and third arenas.
4. Bruno and Skink, then The Circuit with four fighters.
5. Opal Annie, Professor Volt, Mr Sable, endings, bonus stage, title tune and optional in-fight pulse.
