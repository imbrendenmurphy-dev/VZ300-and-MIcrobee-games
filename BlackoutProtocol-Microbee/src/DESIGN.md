# BLACKOUT PROTOCOL — Microbee Premium Plus

An original flick-screen infiltration platformer in the "search the rooms, dodge the robots,
crack the code against the clock" genre. All names, characters, art, sound and layouts are
original to this project.

## Premise

Year 2091. The orbital tether station **HALCYON ARRAY** controls the planet's power grid.
Its custodian AI, **MERIDIAN**, has locked the crew out and scheduled the *Blackout
Protocol*: in 8 hours it cuts the grid for good. You are **Agent Wren**, dropped onto the
upper docking ring with a wrist-deck, a grapple and no backup. Search the station for the
**36 cipher shards** hidden in its fittings, rebuild MERIDIAN's 6 override keys at the
**splice terminals**, and reach the core before the clock runs out.

## Target hardware

| | |
|---|---|
| Machine | Microbee Premium Plus: Z80 3.375 MHz, 1 MB RAM, 32 KB PCG RAM, colour |
| Disk | Microbee DS80 (double sided, 80 tracks, 800 KB), CP/M boot disk, `BLACKOUT` at A> |
| Video | **PAL full screen 336 × 288**: 42 × 24 cells of 8 × 12, 6.75 MHz dot clock, 312-line 50 Hz frame |
| Buffering | Two full 1008-cell pages = 2016 of the 2048 PCG characters, flipped with R12/R13 every frame: no flicker, no tearing |
| Colour | 16 fg/bg colours per 8 × 12 cell; dithered mono fallback for green/amber monitors |
| Memory | Code + engine in the 64 K map; room graphics, tiles, sprite pre-shifts, music and speech samples in the banked 1 MB, streamed per wing from disk |

### Video RAM map

- Screen cell *n* (0–2015) permanently shows PCG character *n* (bank *n* >> 7). Page 0 = cells 0–1007, page 1 = 1008–2015.
- The game draws into a 16-byte-per-cell native buffer in main RAM (12 pixel rows, colour, flags) with a dirty-cell list; `present` copies this frame's and last frame's dirty cells into the hidden page and flips.
- A clean copy of the room (`BACK`) restores the cells under sprites.

## The station layout (the classic plan, expanded)

- **Two kinds of screen.** *Rooms* are full, static, colourful single screens (42 × 22 cells
  plus a 2-row HUD) with several platform levels, in-room lift pads, furniture to search and robots.
  *Lift shafts* are a separate screen: Wren rides a lift platform up and down a tall shaft and the
  whole view **scrolls smoothly**; tunnels open off the shaft at each level, leading to rooms.
- **The grid.** Shafts stand side by side; each room sits between two shafts and has a door on
  each side (at the same or different heights), so the station is a chain of
  shaft → room → shaft → room. The original plan had 9 shafts and 32 rooms; this one has
  **12 shafts and 48 rooms over 6 wings**, plus a hidden 7th wing (bonus rooms).
- **The core** room sits at the bottom of the last shaft and opens only with all six override keys.
- The station map is shown in the wrist-deck: the shafts as columns, rooms as boxes, colour-coded by wing.

### Scrolling the shaft: how it fits in a 3.375 MHz frame

Shaft scenes are built from a few tiles. Each pair of tiles stacked vertically (A over B) gets a
**combo character**; at fine offset *o* (0–11) the combo shows the bottom 12−*o* lines of A and the
top *o* lines of B. While the lift moves:

- Each frame only the ~20–40 combo characters are rebuilt for the new offset (≈12 K T-states), into
  the hidden page's set (page 0 uses PCG bank 1, page 1 uses bank 9), then the pages flip.
- Every 12 pixels (a coarse step) the hidden page's screen RAM is pointed at the next row of combos (924 bytes).
- Wren and the lift platform stay still on screen in ordinary cells, so they never need redrawing.
- Shaft colours are constant down each column, so colour RAM is written once.
- When the lift stops, the view is rebuilt as ordinary cells so Wren can walk off into a tunnel.

Each wing has its own tile set, palette, music and hazard.

| Wing | Theme | Gimmick |
|---|---|---|
| 1. Docking Ring | Cargo bays, cranes | Conveyor floors, crates you can push to reach ledges |
| 2. Hydroponics | Greenhouses, mist | Spore vents that slow you; plants hide shards |
| 3. Cryo Labs | Ice, frost | Slippery floors, freezing beams that make platforms appear/disappear |
| 4. Reactor Deck | Pipes, heat | Rooms go dark: only a cone round Wren and lit terminals show; heat vents on timers |
| 5. Zero-G Observatory | Glass, stars | Low gravity: long floaty jumps, magnetic boots on marked floors |
| 6. MERIDIAN Core | Data halls | Rooms rearrange when you trip alarms; final confrontation |

## Agent Wren

- Run, crouch, ride lifts up and down, and a **vault** — a long, high, rolling leap that clears robots.
- **Search**: stand at any fitting (locker, console, bunk, crate, vending machine…) and hold UP; a progress bar fills. Fittings hold a shard, a gadget charge, a code fragment, or nothing.
- **Grapple** (gadget): swing to ceiling hooks in certain rooms.
- **Security terminals** in rooms take one-use codes found by searching: **SLEEP** (switches off
  the room's robots for a while) and **RESET** (puts the room's lift pads back). Unlike the classic,
  the wrist-deck shows how many of each you hold and terminals say which codes they accept.
- **EMP pulse** (rare gadget): freezes robots for a few seconds without a terminal.
- Death costs **10 minutes** of the clock, not a life; you restart at the room entrance.

## Enemies (all original designs)

- **Patroller** — rolls a floor, turns at edges; some shoot sparks, some fire when they *see* you.
- **Hound** — fast, chases you along a floor once you're on it.
- **Sentry turret** — fixed, sweeps a beam; sometimes a light cone you must stay out of.
- **Warden drone** — floats slowly towards you through the walls; only in rooms with a ticking alarm.
- **Spark ball** — bounces between floors.
- Each robot has a per-room behaviour script, so rooms feel different even with the same robot.

## Splice terminals (the main puzzle)

Each override key is a 3 × 3 grid of circuit tiles. Found shards appear in your **wrist-deck**
in a random colour and rotation. At a terminal you rotate, flip and recolour (with spare
**colour cells** found in rooms) and lay shards over each other until the key's circuit lights
end to end. Hints cost time. Keys open the core.

Smaller terminal mini-games in rooms:
- **Lift override** — a frequency-match tone puzzle to unlock a locked lift.
- **Security camera** — a quick wire-routing puzzle to switch a room's lights or turrets off.
- **Robot recode** — memory game (repeat a tone/colour sequence) to put robots to sleep.

## Quality of life (things the genre classic lacked)

- **Station map** on the wrist-deck: rooms visited, rooms fully searched (✓), rooms with known shards, your position.
- **Searched fittings** stay marked; no wasted time re-searching.
- **Save to disk**: three save slots on the DS80, plus an autosave at each splice terminal.
- **Difficulty**: Story (16 h clock, slower robots), Agent (8 h), Ghost (5 h, no hints, robots see further).
- **Random or fixed** shard placement (seeded run code you can share).
- Remappable keys, joystick, pause anywhere, sound/music toggles, colour/mono switch.
- Optional **assist**: shows the vault arc; brief invulnerability after a death.

## Bells and whistles

- Animated title with the station turning in space, scrolling credits, attract demo playing itself.
- Digitised speech samples from MERIDIAN ("Intruder." / "Access denied." / "Time is short, agent.") on the 1-bit speaker.
- Per-wing music, sound effects for every action, stingers for shards and keys.
- Top-ten table with names and best times, saved on the disk; run statistics at the end (time, deaths, rooms, searches).
- Ending sequence; Ghost-mode ending is different.
- *Vibed by BPM.*

## Milestones

1. **Engine** — PAL 336×288 mode, double-buffered PCG pages, dirty cells, keyboard, test room, Wren walking. ✓
2. **Rooms + shaft** — packed themed rooms, separate smooth-scrolling lift shaft (combo characters),
   room ↔ shaft transitions with a short blanked rebuild. ✓ (4 rooms, 1 shaft)
   *Hardware note:* the Premium Plus holds the CPU off video RAM while a line is drawn (≈2–3 accesses
   per line), so full rebuilds happen with the screen blanked (≈0.2 s) and moving things stay small.
3. **Wren's moves** ✓ — skeleton-animated 24×24 frames (`tools/wren_anim.py`: 8-frame run, turn,
   11-frame forward-flip vault, fall, land, kneel-and-search), runtime shift + mirror tables, floors
   from the room map, falling (off the bottom = −10 minutes), searching with a progress bar, in-room lift pads.
   *Room style:* black walkways (no scenery ink, so Wren never clashes); between walkways, bevelled
   dither-shaded wall panels lit from above (light top row, dim middle, neon trim), girder trusses
   under platforms, themed fittings and painted wall signs.
   *Memory:* ✓ moved to banked RAM — see "Using the 1 MB" below. The COM is now 9.7 KB of code + per-frame tables.

## Using the 1 MB

Port 50 maps any of 32 blocks (32 KB each) at 0000–7FFF; 8000–FFFF is always block 0. Blocks 0 and 2
are the program's own 64 KB. **BLACKOUT.DAT is loaded at start-up into blocks 3 onward** (through CP/M,
128 bytes at a time), and the game copies what it needs into fixed RAM through a 256-byte bounce
buffer, with the switch-and-copy code living in upper RAM (`src/bank.asm`).

| Blocks | Use | Size |
|---|---|---|
| 0, 2 | Program: code, tables, BACK/NATIVE buffers, dirty lists, video window | 64 KB |
| 1 | Spare / save-game scratch | 32 KB |
| 3–4 | Core: Wren's frames, HUD/wrist-deck art, fonts, robot frames | 64 KB |
| 5–12 | Rooms: 48 records (runs + per-room tile sets for unique art, fittings, pads, signs, robot scripts) | 256 KB |
| 13–14 | Shafts: 12 pair maps + tunnel art | 64 KB |
| 15–22 | MERIDIAN speech and sound samples (1-bit, ~8 kHz) | 256 KB |
| 23–25 | Music (per-wing tunes) | 96 KB |
| 26–29 | Title, map, splice-terminal and ending screens (pre-built pages) | 128 KB |
| 30–31 | Runtime: searched-fitting flags, run state, autosave image | 64 KB |

### Four disks (the Premium Plus mounts up to four logical drives)

| Disk | Holds | How it's read |
|---|---|---|
| `BA.DS8` (boot) | CP/M system tracks, our auto-boot CCP.SYS, SAVES.DAT, BLACKOUT.COM, BLACKOUT.DAT (core: Wren, robots, Docking wing), overlays | boots straight into the game; the DAT is read through CP/M at start-up, into blocks 4+ |
| `BB.DS8` | WING2.DAT (Habitat wing rooms) | raw, by the game's own WD2793 driver, the first time a room needs it |
| `BC.DS8` | WING3.DAT (shaft C; later wings 5-6, screens) | the same |
| `BD.DS8` | WING4.DAT (MERIDIAN core; later speech and music) | the same |

Data disks B–D are ordinary CP/M DS80 disks (DIR works) whose single .DAT file starts at block 1 =
data-area logical sector 8; the game reads its sectors directly (`src/fdc.asm`: track-side 4 + L/10,
3:1 skew, IDs 21–30), checks a "BLACKOUT PACK n" signature, and asks "INSERT DISK x" if it's wrong
or missing. Each pack is read once and stays in RAM, so the 960 KB is a cache of all four disks.

### Auto-boot (no Microbee shell)

Disk A boots straight into the game. **It does not use the Microbee shell**: there is no
SHELL.SYS on the disk. The Microbee CP/M boot code in the system tracks loads SHELL.SYS if a disk
has one, otherwise CCP.SYS, at CB00 and jumps to it. Disk A's CCP.SYS is our own 384-byte loader
(`src/autoboot.asm`, built to `build/CCP.SYS`) in place of the CP/M command processor: it resets
the disk system, reads BLACKOUT.COM into 0100 through the BDOS, and runs it, just as typing
BLACKOUT at A> would. Because it only reads, it works with disk A write-protected, and the disk
stays an ordinary CP/M disk (DIR it from any other boot disk). There is no A> prompt when booting
from disk A; the original CCP.SYS stays in `resources/`. A reset or warm boot runs the game again.
Reusable for other Microbee games: change the FCB name in `autoboot.asm` (8 + 3 letters).
Tested: `test/autoboot.txt` (cold boot, disk A write-protected, title reached with no typing) and
the uBonPC window with the four disks.

### Fixed-RAM map (program blocks)

| Address | Use |
|---|---|
| 0100–3FFF | Code, tiles, font, shift/mirror tables, small tables |
| 4000–4FFF | Data window: the room record being built, or the current shaft's pair map |
| 5000–8EFF | BACK (clean scene, 16 bytes a cell) |
| 8F00–8FFF | Bounce buffer for bank copies |
| 9000–CEFF | NATIVE (what's on screen) |
| CF00–CFFF | Wren's current frame + the bank-switch routine |
| D000–DFFF | Dirty-cell lists |
| E000–E1FF | Variables |
| E200–E99B | Room tile map and colour map (collision, searching, pads) |
| E9A0–EEFF | Stack |
| F000–FFFF | Video window (screen / attributes / colour / PCG) |
**Gameplay pass (2026-11-23)** ✓ — first full loop, 11 rooms / 3 shafts / 9 shards / 3 keys:
robots (patrol, shooter, hunter, sentry; sparks; vault over them; 1.5 s grace on entry), deaths
(−10 min, back to the door), fittings with hidden shards / SLEEP / RESET codes (searched ones dim),
security terminals (S = SLEEP robots 20 s, R = RESET lift pads), wrist-deck (W: keys, codes, map
coloured by visited / fully searched), splice lab puzzle (turn three circuit shards to match),
sealed core (opens with all keys) → win page, clock 0 → game-over page, title page.
Engine: pre-shifted, pre-mirrored sprites in the banks blitted by code in fixed upper RAM; objects
redrawn only when they change; game logic runs once per 50 Hz field gone, so busy rooms draw at
25 fps but keep time. Test hook: `poke dbg_r N; poke dbg_side 0/1; pc dbg_room` drops into a room.
Blocks 1 and 3 are CP/M's buffers while it is still running, so BLACKOUT.DAT loads from block 4.

**Sound pass (2026-11-23)** ✓ — `tools/speech.py` (Windows TTS "Hazel", ring-modulated, 1-bit
delta-sigma at ~28.7 kHz, on disk D; 9 original MERIDIAN lines), `tools/music.py` (8 original
two-channel tunes: title, wrist-deck, win, lose, three wing stings, key online), `src/sound.asm`
(music player 122 T/pass, speech player in upper RAM, effects: steps, vault, land, search ticks,
lift/pad hum, sleep, zap, death).
**Polish pass** ✓ — `tools/reach.py` proves every fitting, terminal and door is reachable (walk,
fall, 9-cell vault, pads) and gates the build; Splice Lab's upper floor got a pad; hunters now
run at Wren's pace.

### Plan for the remaining wings
The station grows to 12 shafts (A–L) and ~48 rooms; each wing spans two shafts and the 8 rooms
around them, lives on its own pack (disks B–D), has its own palette, tile accents, sting and one
mechanic of its own (one new engine feature per wing):

| Wing | Shafts | Mechanic |
|---|---|---|
| 1 Docking (done, reworked) | A–B | conveyor belts that carry Wren |
| 2 Hydroponics | C–D | spore vents: Wren walks at half speed in the mist |
| 3 Cryo Labs | E–F | ice floors: Wren slides on after he stops |
| 4 Reactor Deck | G–H | steam vents that fire on a timer (deadly) |
| 5 Zero-G Observatory | I–J | low gravity: longer, floatier vaults, slow falls |
| 6 MERIDIAN Core | K–L | laser gates that switch with the alarm cycle |

**Built (2026-11-23):** 47 rooms, shafts A–L. Wings 1–5 are generated by `tools/wings.py`
(themes, floor plans with gaps, pads, furniture, fittings, signs, robots, the wing mechanic), every
room proven by `tools/reachlib.py` before it's accepted; doors are kept fair (no shooters on a door's
floor, patrols 11+ cells clear; tested: 94 door arrivals, no deaths in 6 s). Each wing hides its key's
3 shards (18 in all) plus SLEEP/RESET codes; each wing has a splice terminal for its own key; the core
(east of L) needs all six. Mechanics: conveyors (docking), spore mist = half speed (hydroponics), ice
momentum (cryo), steam vents 1 s on / 2 s off (reactor), low gravity: 52-frame, 34 px vault and slow
falls (observatory), laser gates 2 s on / 1.5 s off (core). Shafts are tinted per wing. Disks: A =
wing 0, B = wings 1–2, C = wings 3–4, D = wing 5 + core + speech.
**Architecture per wing** (`tools/styles.py`, so wings differ even on a mono monitor): Docking =
bevelled panels and girder trusses; Hydroponics = glasshouse (arched arcade, diamond glazing,
mullions, planter ledges, vines under platforms); Cryo = ice-block courses, rime, icicles;
Reactor = pipe bundles with flanges and risers, chevron skirting, I-beams; Observatory = open
starfield, curved hull ribs, portholes, thin struts; Core = circuit board (traces, pads, chips,
data buses, data-stream skirting, grids). Each style has its own side walls and ceiling.
**Playthrough and balance pass (2026-11-23):**
- `tools/playtest.py` writes a scripted completion run (test hook `dbg_goto` keeps the game state):
  all 18 shards found with the real search, six splice terminals → six keys, Antechamber → shaft L →
  core → MERIDIAN's terminal → win. Passes. It caught a real bug: the Hydroponics splice terminal
  could be skipped by the generator (now guaranteed, and gen.py asserts every wing has one).
- Frame rate across all 47 rooms: 25–50 fps (logic is field-timed, so speed and the clock hold).
- Door safety: 90 door arrivals, standing still 6 s, no deaths.
- Difficulty climbs by wing: Docking gentle (1 hunter), Hydroponics 1 robot/room, Cryo 1–2 with
  shooters, Reactor 1 + steam vents, Observatory 2/room, Core 2 + laser gates; ≤ 1 hunter a room;
  every ordinary room guarded; splice rooms gentle.
- Clock runs ~3× real time (CLOCK_FRAMES 17): 8 game hours ≈ 2 h 40 min of play; a death (−10 game
  min) ≈ 3½ real minutes. 633 fittings in all (≈ 21 min to search everything).
The information screens moved to an overlay (`src/overlay.asm` → BLACKOUT.OVL, block 31), loaded
into the data window only while a screen is up; the COM is 15.2 KB.

4. Robots and their scripts, deaths and the clock.
5. Wing 1 complete with all its rooms and shards; wrist-deck, map.
6. Splice terminals and mini-games.
7. Wings 2–6, disk streaming of wing data from banked RAM.
8. Front end: title, options, saves, high scores, speech, music.
9. Polish, balance, attract demo, release disk + README.

**Save games (2026-11-23)** ✓ — `SAVES.DAT` (4 KB, CP/M block 2 on disk A = data-area logical
sectors 16–19), one 512-byte sector a slot, read and written straight through the WD2793
(`src/save.asm`). Slot 0 is the autosave, written each time a key comes online; slots 1–3 are
the player's (wrist-deck **S**). The title's **L** opens the load page, which lists each slot's
wing, keys, shards and time left. A write-protected disk A gives "DISK A LOCKED". The save and load
pages are a second overlay (`src/overlay2.asm` → BLACKOUT.OV2, block 30); `ui.asm` is now resident
so both overlays share the page interpreter. SAVE_BUF borrows the last-frame dirty list (D800), so
the autosave presents twice first to empty both lists. Tests: `test/save.txt` (save, reset, load,
write-protect) and `test/complete.txt` (all six keys, autosave checked on the disk image).

**Difficulty levels (2026-11-23)** ✓ — after SPACE on the title, a CLEARANCE page (overlay 2) picks
Story / Agent / Ghost. `skill_apply` (`src/save.asm`) copies a row of `sk_tab` into the live tuning:

| | Story | Agent | Ghost |
|---|---|---|---|
| Fields per game second (clock) | 25 (~4 h play) | 19 (~3 h) | 16 (~2 h 35) |
| Minutes lost per death | 5 | 10 | 15 |
| Robot gun cool-down (fields) | 110 | 75 | 50 |
| Grace on entry / after a death | 100 | 75 | 50 |
| Robots walking | all half speed | slow ones half speed | all full speed |
| Hunters chasing, shots | half speed, slower shots | full | full |

The level is stored in the save record (byte 13) and shown as the colour of the slot's name (green,
white, red). Test hooks and `test/complete.txt` run on Agent. Test: `test/level.txt` (choose Ghost,
save, reset, load: skill restored).

**Balance pass 2 (2026-11-23)** — `tools/balance.py`: a bot in the real game enters every room on
every level, stands at the door 4 s, then runs for the far side vaulting every half second (a blind,
hurried player); a robots-asleep run gives the baseline (0 deaths: every death is a robot).
- Door safety on all three levels: 0 deaths in 46 arrivals each.
- Blind-run deaths, 46 rooms: Story 25, Agent 27, Ghost 40 (the bot can't use Story's slower robots;
  a player timing vaults can, so treat this as relative).
- Fixed: hunters on a door floor (they met Wren on arrival: Agri Control, Reactor Control) now
  patrol; splice rooms keep no hunters and nothing walks the splice terminal's floor (Agri Control
  went from 3 deaths to 0).
- Clock model (≈ 2 h of death-free play: 3/4 of 633 fittings searched, rooms crossed twice, lifts,
  splices): the old Agent clock left ~12 deaths to spare and Ghost ~3, so Agent is now 19 fields
  per game second (~16 deaths to spare) and Ghost 16 (~7); Story keeps 25 (~48).
- Test-harness lesson: never `pc` jump while speech is playing (its bank is paged in at 0000);
  wait for `until loop` first.

**Rotoscoped Wren (2026-11-23)** — Wren's run, stand and vault are now traced from Eadweard Muybridge's
*Animal Locomotion* (1887, public domain; `ref/`): Plate 60 (man running, 10-frame cycle; frames 6–10
are 1–5 with limbs swapped) and Plate 363 (running somersault, 12 frames). Joint angles were read by
hand off gridded enlargements (`tools/trace.py` makes them; `tools/rotofit.py` was an automatic
fitting experiment, too unreliable to use) and drive the skeleton renderer in `tools/wren_anim.py`,
so the motion is real but the body stays a clean 24 × 24 silhouette. Run is now 10 frames
(`RUN_FRAMES`, footfalls on frames 1 and 6). Turn, fall and kneel are still hand-posed.
Balance after the rotoscoped frames: robot hits use fixed boxes (body box, and a ball while
vaulting), not the drawn frames, so nothing changed by design. Bot re-run: Story 24, Agent 27,
Ghost 47 blind-run deaths (was 25 / 27 / 40), 0 door deaths. Starting the bot 3 or 7 fields later
gives Ghost 40 and 42, so the spread is about ±4 from timing alone (footstep sounds now land on
different frames). `BAL_SHIFT=n python tools/balance.py` measures it.

**Hardware feedback pass (2026-11-23)** — from the first run on a real Premium Plus:
- **ESC** in a room or a shaft: "QUIT? Y/N" on the bar; Y goes to the title (L loads a save there),
  N or ESC again carries on (the clock stands still while asking). Shown on the title's controls.
- **Searching**: the pick tries the cell behind Wren, then the side she faces, then the other side,
  and either half of a two-cell fitting finds its item (before, the right half always said NOTHING
  HERE). Searched fittings are now half-toned (a checkerboard through the pixels) as well as dimmed,
  so they show on a mono screen; both halves of a two-cell fitting are marked.
- **LOADING...** on the bar whenever a pack is read from disk B–D; dots while disk A loads at boot.
- **Easier levels**: two more knobs per level — hunters stand down (patrol) on Story, and the robot
  touch box is trimmed 2 / 1 / 0 half-pixels each side (Story / Agent / Ghost); Story gun cool-down
  150, grace 3 s; Agent cool-down 90, grace 2 s. Bot blind-run deaths: Story 18, Agent 23, Ghost 41
  (was 24 / 27 / 47), 0 door deaths.
- **Speech on real hardware**: re-encoded as clipped speech (the speaker flips where the voice
  crosses zero) instead of 28.7 kHz delta-sigma, which a real Microbee speaker barely reproduces.
  `tools/speech.py` MODE = 'sigma' restores the old encoding.
- **Title music**: a new ~94 s piece in sections (intro, theme, brighter middle, bridge, theme over
  a walking bass, ending; melody kept low, bass alternating octaves) played once, not looped. It
  lives in the core pack (`title_far`, 1278 bytes) and plays from the D800 scratch buffer.
- **Attract mode**: when the tune ends untouched, a demo (`src/demo.asm`): Wren plays by herself for
  ~45 s at Agent level from Cargo Bay 7, vaulting robots she sees coming, searching what she passes
  now and then, turning at walls, out through doors and along the shafts; then the title again (the
  welcome line only the first time). Any key or ESC ends it.
- Tests: `test/qol.txt`, `test/esc.txt`, `test/load.txt`, `test/attract.txt`; tests now wait for
  `mus_play` (the title no longer uses `mus_loop`).

**Disks B–D on a real Premium Plus (2026-11-23)** — on the user's machine (SD-card disk images,
"Boot Mode & Disk Image Utility") the game said INSERT DISK B and NO VOICE although BA–BD.DS8
were mounted on A–D: CP/M reads all four, but the game's own direct WD2793 reads don't reach
B–D there. So `load_assets` now also reads `B:WING2.DAT`, `C:WING3.DAT`, `D:WING4.DAT` through CP/M
at start-up, into the same banks the direct reader would use, and marks those packs loaded; the
direct reader is only a fallback for a drive that was empty at boot. Before touching a drive it
asks the BIOS (SELDSK) whether it exists, so an empty drive is skipped instead of stopping on CP/M's
"Err On B: Select" (which would loop with the auto-boot). Disk images renamed BA/BB/BC/BD.DS8 (8.3
names for the SD card). `fdc_wait` now times out (~3 s) so a save can't hang where the direct
access doesn't answer; it reports SAVE FAILED.
Test disk **BT.DS8**: boots to the ordinary A> prompt (the real CCP.SYS) with the game and
**FDCTEST.COM** (`src/fdctest.asm`), which does the game's direct reads on A–D and prints every
status byte, the byte count and the first bytes (reference run: `outputs/fdctest_reference.png`).
The title shows "NO VOICE: DISK D NOT FOUND" when disk D couldn't be read.

Shaft lifts (2026-11-23): Q/A **or the arrow keys** ride the lift (it read only the letters before), from anywhere on the platform (±10 half-pixels of centre, was ±4); Wren is centred when the ride starts. Test: `test/lift.txt`.
