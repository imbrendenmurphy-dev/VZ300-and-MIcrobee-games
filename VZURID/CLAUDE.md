# CLAUDE.md — VZURID (Uridium-style shoot-'em-up for the VZ300)

Handover from Claude chat to Claude Code, 21 Nov 2026. Read all of this before changing anything.
Phases 1 and 2 of the brief (`BRIEF.md`, the user's original text) are built. Nothing has been
tested on a real VZ300 yet.

Credits line for anything user-facing: **VIBED BY BPM 2026** (the user's standing preference: never
"code by Claude" or similar). The splash screen already shows it.

The user (BPM) is a retro collector, not a programmer (basic BASIC / Z80 knowledge). He tests on his
real VZ300 and reports back, usually with photos. Explain results in plain words. He hates
insta-death and wants his games forgiving (health bars, several hits per life); Phase 2 follows that.
He wants progress kept on his PC and in the GitHub repo `imbrendenmurphy-dev/VZ300-and-MIcrobee-games`
(folder `VZURID/`).

---

## 0. Quick facts

| | |
|---|---|
| Status | **Phase 2 of 5 done (combat engine), emulator-verified only.** Real hardware: untested. |
| Output | `release/VZURID2.VZ` (13,025 bytes, loads and starts at `$8000`). Phase 1 binary: `release/phase1/VZURID1.VZ`. |
| Build | `py build.py` (Windows) or `python3 build.py`. Python 3 + **Pillow** (`pip install pillow`; used by `gen_assets.py` and the test harness only). |
| Handover check | A clean `py build.py` must reproduce `release/VZURID2.VZ` with MD5 `577cb1433d47fb1a1bc5263091fde6ee`. |
| Code/data size | `$8000`-`$B2C8` (13,001 bytes + 24-byte VZ header). Hard ceiling: must stay below `$C000` (ring buffer); `build.py` asserts this. |
| Tools | Own two-pass Z80 assembler (`tools/z80asm.py`) and Z80 emulator (`tools/z80emu.py`, Zilog T-states, own code, no third-party). **No network / no installs were available when this was written**: everything runs on stock Python plus Pillow. |
| Controls | M left, `,` right, Q up, A down, `.` or SPACE fire. Joystick (IN `$2C` bits0-3 up/down/left/right, IN `$2E` bit4 fire, active-low) is coded but **never tested**. |

---

## 1. Purpose, status, completed functionality

Goal (from `BRIEF.md`): a complete, polished Uridium-style game for the VZ300 in native MODE(1)
(128x64, 4 colours), BennVenn SD + 128K, snow-free 50 fps bidirectional scrolling in single-pixel
steps, a convincing multi-frame 180-degree flip, 15 dreadnoughts, landing/destruction, audio,
presentation, hardware testing. Five phases; the user said "yeah that'd be grouse" to the Phase 1
architecture and "continue phase 2" afterwards.

### Done (emulator-verified unless stated)
Phase 1:
- 128x56-pixel playfield (now 128x48, see Phase 2) redrawn every field from a pre-shifted ring buffer; 1-pixel scroll both ways; momentum flight (8.8 fixed point, 24-bit world position, wraps at 1536 px).
- One dreadnought: 192x6 tiles of 8x8 pixels (12 screens wide, wraps), generated from tiles in `gen_assets.py` (plates, seams, rivets, raised blocks, vents, trench, pipes, hazard stripes, engine glow, runway, dish, turret sockets).
- Ship with 13 frames: 9-frame horizontal "squeeze" flip (0 = facing right, 4 = edge-on, 8 = facing left) plus 4 bank frames. The flip is a state machine stepping every 2 ticks toward a target, so it can be reversed mid-flip, and thrust follows the key immediately (never a cutscene).
- Enemies, firing, collisions, explosions, score.
Phase 2:
- 48-row playfield (rows 16-63) + 16-row HUD (rows 0-15): score (units of 10, drawn with a trailing 0), lives, wave number, 5-pip energy bar (green >= 4, yellow 2-3, red <= 1), debug counters SL (min spare time, 35 T units) and LT (late frames).
- Forgiving damage: 5 energy, 3 lives. Hit = -1 energy + 60 frames invulnerability (blinks, 4 on / 4 off). Hull "block" tiles (`SOLID` table) hurt and knock the ship back (speed set to +/-384). 0 energy: ship explodes (36 frames), respawns with full energy and 120 frames invulnerability. Game over: waits 90 frames, then fire restarts (`game_reset`).
- 4 formation waves (line, V, divers, column), spawned ahead of the ship in the direction it faces; next wave 60 frames after the last mobile enemy is gone. Divers (type 1) home in every 8 frames and fire aimed shots.
- 10 gun turrets (`TURLIST`, generated from `turret()` calls in `gen_assets.py`), 3 hits to kill, aimed 8-direction shots, 2 turret slots, spawned from a rotating cursor when they come within 128-176 px of the screen edge; a dead turret stays dead until the game is restarted. The gun is a sprite on a hull "socket" tile (the tile art is a dark empty socket on purpose, see 6).
- Enemy bullets (3 slots, screen-space, packed velocity), score per kill (drifter 10, diver 20, turret 50).

### Not done (see section 9)
Sound/music, title/attract screens, hi-score, the other 14 dreadnoughts, landing/take-off, ship destruction sequence, level progression, use of the 128K, joystick verification, real-hardware testing, quit-to-shell path.

---

## 2. Target hardware, memory, constraints

Facts below marked (HW) come from the user's earlier hardware tests (BENCH.VZ, RASTEST, bank probes, in his stored notes), carried over, **not re-measured here**.

- VZ300, PAL, BennVenn SD loader with 128K RAM. Program is a plain `.VZ` that loads at `$8000`. The brief mentions a ~31,200-byte load limit; the current file is 13 KB.
- MODE(1): latch `$6800` = `$08` (colour set 0: 0 green, 1 yellow, 2 blue, 3 red, speaker off). VRAM `$7000`-`$77FF`, 32 bytes per row, 64 rows; pixel packing `p0<<6|p1<<4|p2<<2|p3` (leftmost pixel in the high bits). 4:3 screen, so pixels are taller than wide (HW).
- Field = **70,630 T**, 312 lines (about 226.4 T per line), field sync (FS) low for 56 lines (HW). FS is bit 7 of any read from `$68xx` (the code polls `$68FF`). Row `r` of the picture is displayed `120 + 3r` lines after the FS fall (HW, BENCH.VZ colour-set test). Writing VRAM during the picture costs no extra T-states and showed no snow (HW, BENCH.VZ). **Not yet confirmed with this program on the real machine.**
- Keyboard: active-low, 6 bits per row, address bit r low selects row r. Row `$68EF`: M bit5, SPACE bit4, comma bit3, full stop bit1 (HW: bit 0 is the last key of each row). Q is `$68FE` bit4, A is `$68FD` bit4.
- BennVenn banking (HW): port `$37` bit0 DOS RAM/ROM, bit1 selects a 10K bank at `$4000`-`$67FF`, bit2 swaps the 18K at `$B800`-`$FFFF`; only two separate 10K banks were found. **VZURID does not use banking at all yet.** If the program ever calls the SD DOS at run time it must not touch `$FA00`-`$FFFF` (HW) and must handle the stack/interrupts as VZ-DECK and Dracula's Castle II do.
- Start-up executes `di` and sets `SP = $FFF0`. The code never re-enables interrupts. **Whether the loader hands over with interrupts enabled and how ROM IM1/`$7800` vectors behave has not been tested on hardware.**
- A stock VZ has no reset button: don't design tests that need one.

### Memory map (all addresses are in `src/engine.asm` equates)

| Range | Contents |
|---|---|
| `$8000`-`$B2C8` | code + data (`engine.asm`, `combat.asm`, generated `build/assets.asm`, `build/gen_blocks.asm`) |
| `$C000`-`$E3FF` | ring buffer `RING`: layout `[row 0..47][phase 0..3][slot 0..47]`, row stride 192, phase stride 48 (9,216 bytes) |
| `$F000` / `$F040` | `RAWA` / `RAWB`: the two raw 48-byte hull columns being converted |
| `$F100`-`$F1FF` | variables `V` (cleared at start by `clear_vars`); sub-areas: `ENM` `V+$40` (6 x 10 bytes), `BUL` `V+$80`, `EBUL` `V+$8C`, game state `V+$A0`.. |
| `$F200` | `SPT` sprite records (14 x 10 bytes) |
| `$F300` | `BHEAD` band list heads (6 words) |
| `$F380` | `TURALIVE` (not cleared by `clear_vars`; set in `game_reset`) |
| `$FFF0` | stack top |

---

## 3. Files

```
BRIEF.md              the user's original brief (read it)
README.md             user-facing readme (measured numbers, what is unverified)
CLAUDE.md             this file
build.py              generates assets, assembles, writes build/vzurid.bin/.sym and build/VZURID2.VZ
src/engine.asm        main loop, frame sync, render, sprites, flight/flip, ring generation, collisions
src/combat.asm        Phase 2: player state, waves, turrets, enemy bullets, HUD
tools/gen_assets.py   tiles, hull map, sprites, font, strings -> build/assets.asm + preview PNGs
tools/gen_blocks.py   generates the unrolled CHAIN / copy_nosplit / copy_split / SBCHAIN -> build/gen_blocks.asm
tools/z80asm.py       assembler (see 8 for its quirks)
tools/z80emu.py       Z80 emulator, Zilog T-states, hooks on_read/on_write/on_in/on_out
tools/vztest.py       virtual VZ300: keyboard rows, FS timing, beam model, per-frame work/margin records
tools/run_tests.py    400-frame scripted flip/scroll/fire scenario
tools/play_test.py    bot gameplay test (see 7)
tools/profile.py      STALE: written for the Phase 1 scenario (uses `render` as the frame start). Use `PROF=a,b` with play_test.py instead.
release/              VZURID2.VZ (and phase1/VZURID1.VZ)
screenshots/          emulator renders
build/                generated, git-ignored; created by build.py
```
`engine.asm` includes `combat.asm`, `../build/gen_blocks.asm` and `../build/assets.asm`; it ends with label `prog_end`.
Some header comments in `engine.asm` still describe Phase 1 (56 rows, "Phase 1 engine"). The code is right, the comments are stale; do not trust them over the equates.

---

## 4. Rendering architecture (the core idea; preserve it)

**Full redraw every field.** Each frame the whole 128x48 playfield is rewritten from the ring buffer with an unrolled `LDI` chain (16 T per byte, the fastest simple block copy; 32 bytes per row). Sprites are then drawn over the fresh background, band by band (6 bands of 8 rows), always ahead of the beam. There is no dirty-rectangle logic and no save/restore of backgrounds: the copy *is* the restore.

**Pre-shifted ring.** The hull is stored as 4 pixel phases (0-3 pixels of shift) so a 1-pixel scroll is just a different source pointer. X = world pixel position; byte-column `B = X>>2`, phase `= X&3`, ring slot `= B mod 48`. The ring is 48 byte-columns, window is 32, so the window wraps in the ring about 2/3 of the time. Wrap is handled **without branches in the copy**: `copy_split` calls into the `CHAIN` at computed entry points (`entry A = CHAIN + 2*(slot-16)` copies up to slot 47, `entry B = CHAIN + 2*(48-slot)` copies the rest from slot 0); the two `call` targets are `jp 0` thunks patched each frame (`thunkA`/`thunkB`), and the band routine pointer in `render` (`.rbcall`) is patched to `copy_nosplit` or `copy_split`. Pointer maths after a split row: `hl -= 48` then `+= 208`; non-split: `hl += 160`.

**Ring maintenance (`ring_update` / `job_step`).** Counters `ringRc` (columns from B to the newest generated column, target 38) and `ringLc` (columns behind B, target 10); `Rc + Lc <= 48`. Scrolling by `d` columns does `Rc -= d, Lc += d`. New columns are produced by a *staged job*: stage 1 builds the two raw columns (`rawcol` from the `TILE0`/`TILE1` tables with 8 unrolled `LDI`s per tile), stages 2-7 each convert 8 rows (`gp_rows`: phases 1-3 by 16-bit shifts, `add hl,hl` x2 per phase, written through `IX` displacements -72/-24/+24/+72, `IX = RING+slot+72` advancing by 192 per row; phase 0 is stored straight from `A`). A column therefore costs 7 stages of about 2-3K T each. **How many stages run per frame is decided in `ring_update`** from the previous frame's spare time (`lastSlack`, measured in `frame_wait`): 1 stage if < 100 loops spare, 2 if < 200, else 3, plus extra stages when `ringRc` < 35 (+1) or < 34 (+3 total) or `ringLc` < 4 (+2). This smoothing is what removed the generation spikes (see 6).

**Hull data.** 192 tile columns x 6 tile rows, column-major (`HULLMAP`, 6 bytes per column), 48 tiles used, `TILE0`/`TILE1` give the left/right byte of each tile row. `HULLMAP` is in RAM (the program is loaded into RAM) so it can be edited at run time, but the ring already holds baked columns, which is why turrets are sprites (see 6). `SOLID[tile]` marks damaging tiles (names starting `blk` or `dk`).

**Sprites.** Pre-shifted x4 phases, interleaved `[mask, data]` bytes. Class table `CLSTAB` (wb, h, rowlen, phasesz): 0 ship 16x7, 1 enemy A 12x7, 2 enemy B 8x6, 3 player bullet 6x2, 4 explosion 12x7, 5 turret gun 8x6, 6 enemy bullet 4x3. `addspr` clips (left skip / right clip), builds a 10-byte record (`y, h, vis, dcol, srcL, srcH, hladj, deadj, nextL, nextH`) and **links it into a per-band singly linked list** (`BHEAD`, band = `(y+h-17)>>3`); records are pushed LIFO, so build order is ship first (drawn last = on top), then bullets, enemy bullets, enemies. `band_sprites` walks the list after each band's copy. `drawspr` has a fast path (`hladj == 0`): `SBCHAIN`, an unrolled 5-byte masked blit (`ld a,(de); and (hl); inc hl; or (hl); inc hl; ld (de),a; inc de`, 7 bytes of code per byte of sprite) entered at `SBCHAIN + 7*(5-vis)` by patching `.rcall`; the slow path (`drawspr_slow`) handles clipped sprites. Enemies whose screen x is `$7FFF` (off screen) are skipped in `build_sprites`.

**Beam discipline.** `frame_wait` polls FS (`$68FF` bit 7), counts spare time in 35 T loop units (`minSlack`, `lastSlack`), and counts a late frame (`lateCnt`) when FS is already low on entry. Order per frame: `frame_wait` -> `status_update` (HUD, drawn first because it is at the top of the screen and the beam has not reached it yet; the earlier version drew it after `render` and tore) -> `render` -> `logic`. The render finishes each row before the beam reaches it; the first deadline (row 16) is about 38K T after FS falls.

### Timing numbers worth keeping in your head
- `CHAIN` copy of 48 rows is about 25.5K T per frame (the floor), `copy_split` overhead about 3.7K when wrapping.
- Sprite pipeline (build + addspr + drawspr + SBCHAIN + band lists) about 15-25K T per frame when busy (about 2-3K T per sprite).
- Ring generation about 15K T per column, 0.375 columns per frame at max speed = about 5.7K T per frame.
- Field budget 70,630 T.

---

## 5. Flight and gameplay model

Momentum in 8.8 fixed point: `ACCEL 16`, `FRIC 8`, `MAXSPD 384` (1.5 px/frame; 2 px/frame did not fit the frame budget). Position is 24-bit (fraction + X 0..1535 with wrap). Flip: `flipF` 0..8 moves toward `flipTgt` every `FLIPDIV = 2` ticks. Ship screen x drifts 1 px/frame toward 36 (facing right) or 76 (facing left). Vertical movement 1-2 px/frame within `YMIN 16`..`YMAX 57`, sets bank frames. Fire cooldown `FIRECD 7`, bullet speed `BSPD 5`. Collisions are AABB (with forgiving shrink for the ship). `hull_check` samples three points under the ship every other frame and is skipped while invulnerable (so a ship can fly *through* a block while the 60-frame shield lasts; this is a known soft spot). RNG: xorshift16 (`rnd`, returns A, clobbers HL only).

---

## 6. Important decisions, and what failed (do NOT reintroduce)

Decisions:
1. **Full redraw from a pre-shifted ring** instead of any partial update: the VZ has no hardware scroll, VRAM writes are as fast as RAM (HW), and the copy doubles as sprite background restore. Don't replace it with shift-in-place scrolling.
2. **Staged column generation scheduled by measured spare time.** Do not generate whole columns in one frame.
3. **Playfield cut from 56 to 48 rows** (HUD 16 rows) to buy about 5K T per frame; the HUD also gives room for energy/lives/wave. Map rows went 7 -> 6 (`MAP_ROWS`); art designed for 7 rows is clipped at the bottom (see 8).
4. **Max speed 1.5 px/frame.** 2.0 px/frame needed about 66K T average and overran constantly.
5. **Turrets are sprites on a "socket" tile, not hull art**, because the ring is baked and cannot show a destroyed turret promptly. The original red/yellow turret tile art was replaced (override block in `gen_assets.py` just before `assert len(TILES) < 64`) with a dark empty socket so the red/yellow gun sprite is visible and a dead turret reads as an empty socket.
6. **Damage is health-based, never insta-death** (user preference).
7. **HUD drawn at the start of the frame and dirty-checked** (only redrawn when its value changed; one field per 4 frames in a rotating table `HUDJT`). The game-over message goes through `hudmsg` so it is also drawn at frame start.
8. Linked list per band for sprites, `SBCHAIN` fast path, coarse y-rejection in `collisions`, off-screen skip, `hull_check` every other frame: all recovered real time, keep them.

Failed or rejected (learned the hard way):
- Phase 1 first build: 67K T mean, 183 of 400 frames late at speed cap 704 (2.75 px/frame). Fixed by the items above, not by one trick.
- Generating up to two columns per frame in one go: 12-15K spikes. Splitting into halves still left 70K+ frames; the 7-stage job with slack-driven scheduling fixed it. Setting the ring "urgent" thresholds too high (Rc <= 36) forced extra stages and brought the spikes back (now 35 / 34).
- Drawing the HUD in `logic` (after `render`): the beam was inside the HUD rows (writes landed mid-row). Do HUD work before `render`.
- **Never call a routine that loads `IX` from inside a loop that uses `IX` without saving it.** `fire_aimed` used to load `IX` for the bullet table and corrupted the enemy loop (symptom: `waveNo` and `lives` overwritten, 193 "waves"). It is now a wrapper (`push ix / call fire_aimed_in / pop ix`).
- Assembler: a **global label inside a routine resets the scope of `.local` labels** (`rb_call:` broke `.band`; renamed to local `.rbcall`). `djnz`/`jr` range is checked: long loop bodies need `dec b / jp nz`. Adding code often pushes a `jr` out of range; the build fails loudly.
- Considered on paper and **rejected, never built** (so no numbers measured): `push/pop` stack-based copy (every register pair is data, so there is no free register for the source pointer; with shadow registers the gain is about 7%, not worth the complexity); storing each column twice to avoid ring wrap (extra generation cost cancels the saving); a 64-column ring (no gain). A "full pre-shifted hull held in banked RAM" idea is **not** rejected, just not tried (needs the 128K bank work in Phase 3).
- Phase 1 summary said speed 1.5 px/frame "feels" slower than wished; this was never judged by the user on hardware.

---

## 7. Testing procedures and verified results

All results are **emulator-only** (own emulator, field model 70,630 T, beam model: row `r` shown `120+3r` lines after FS fall). Real-hardware results: **none**.

Commands (run from the `VZURID` folder; on Windows use `py`):
- `py build.py` then `py tools\run_tests.py 400`: scripted scenario (fly right, rapid fire, flip at 120/230/340/352, climb/dive). Writes screenshots to `build\shots`. Last result: work min 34.8K / mean 54.1K / max 76.7K T; 2 of 400 frames over budget; 0 rows written after the beam; 0 beam-row write conflicts after frame 0.
- `py tools\play_test.py 3000 <seed>`: a bot flies, hunts enemies and turrets, fires, steers; also hits game over and restarts. Prints work stats, late frames, rows drawn after the beam, beam conflicts, final state. Env vars: `PROF=a,b` per-routine profile of frames a..b; `DBG=a,b` per-frame sprite count, ring counters and job stage. Screenshots every 500 frames in `build\play`. Results (3000 frames each): seed 1: mean 53.7K, p99 68.6K, max 72.8K, 12 over budget (0.40%); seed 3: 9 over (0.30%); an earlier build 16 (0.53%). Overruns cluster when 4 enemies + a turret + bullets + full-speed scrolling coincide (around frames 240-272).
- `vztest.py` measures the frame start at label `frame_sync_ret` and checks every VRAM write against the beam (`beam_conflicts`) and the row deadline (`late_rows`). It only treats rows >= 16 as playfield.
- Hardware facts in section 2 marked (HW) are the only things measured on the user's real machine, and by other programs.

Verified in the emulator: scrolling both ways, flip (screenshots), no late rows, no HUD tearing, waves, turrets, enemy and player bullets, energy/lives/game over/restart, hull damage and knock-back, no crashes over 3 x 3000 frames.
**Not verified at all:** anything on a real VZ300 (timing, tearing, snow, loader hand-over/interrupt state, joystick, feel and difficulty), left-facing wave spawns and the left-going hull-damage path beyond what the bot happened to do, visual quality of the 6-row hull (screenshots only), sound (none).

---

## 8. Known bugs, limitations, quirks

- About 0.3-0.5% of frames in worst-case bot play exceed the field (one dropped field each; not a tear). Cause: sprite pipeline cost. This is the main engineering problem left.
- `lastSlack`-driven scheduling has no hard guarantee; at sustained heavy load the ring can run low (urgent stages kick in).
- Hull art was drawn for 7 tile rows; the bottom row is clipped, so some structures (pipes, runway) look cut. Cosmetic; redo the sections in `gen_assets.py` for 6 rows.
- HUD debug counters SL/LT are still on screen. Score shows units of 10 plus a trailing 0 and digits go odd above 9999 (99,990 points).
- Invulnerable ship flies through hull blocks.
- Enemy bullets are in screen space (they slide against the hull as it scrolls); fine for tiny shots, would look odd for big ones.
- `pc_row` is a global the text routines depend on; set it before `putchar`/`putstr`/`putdec4` (a forgotten set once drew HUD numbers in the playfield).
- No quit/return-to-shell path. A VZ-DECK compatible exit (switch BennVenn mapper to BIOS with port `$37 = 0`, jump to ROM start) worked for VZ-TREE per the user's notes but is not implemented here.
- Assembler limits: no macros, `name equ expr` only, 1 expression per operand, hex as `$1234`. `tools/z80asm.py` is homemade: if it disagrees with a real assembler's idea of an instruction, check the opcode tables first.
- `TURALIVE` lives outside the cleared variable page: re-initialised by `game_reset`.
- Splash title text is `VZURID PHASE 2`; change in `gen_assets.py` strings.

---

## 9. Outstanding work and priorities

0. **Get it on the real VZ300 first** and ask the user for photos/feedback: does it load from the BennVenn loader, is the scroll snow/tear free, do the SL/LT counters stay sane, joystick, speed/difficulty feel, flip feel. Fix anything the hardware shows before building more. Check the loader's interrupt state (the code does `di` on entry).
1. **Cut sprite cost** (target: zero late frames in the bot test, then raise `MAXSPD` back toward 512). Ideas not yet tried: precompute the VRAM destination and `SBCHAIN` entry in `addspr` (a lookup of `y*32` instead of five shifts); remove the many `as_*` memory round-trips in `addspr` (about 900 T per call now); a smaller or cheaper enemy A sprite; fewer simultaneous enemy bullets; merge `build_sprites` and `addspr`.
2. **Phase 3 (full game):** 15 dreadnoughts (map data per ship; probably compressed and loaded from the 128K banks or generated; remember the ring and hull generation read `HULLMAP`/`TILE0`/`TILE1` in main RAM), landing/take-off, ship destruction sequence, progression, lives/bonus rules, difficulty curve (keep it forgiving). Note memory is tight below `$C000` only if code grows past 16 KB; there is about 11 KB of room before `$C000`.
3. **Phase 4:** sound/music (beeper; the user has a stated music style in his notes), title and attract screens, hide SL/LT behind a debug key, hi-score, tidy the hull art for 6 rows, optional palette tweaks. Credits: "VIBED BY BPM 2026".
4. **Phase 5:** hardware test report, README with honest measured vs untested sections, release folder, screenshots, GIF, blurb (the user's usual release package is described in his notes: blurb with tech specs, separate screenshots of each stage/enemy/boss/title, release zip, plain-text copy for YouTube/Facebook).

Working rules that apply to every phase: keep emulator results and hardware results clearly separate; never claim a snow-free or 50 fps result that was only seen in the emulator; keep changes small and re-run both test scripts after any engine change; rebuild must stay deterministic.

---

## 10. GitHub

Repo: `https://github.com/imbrendenmurphy-dev/VZ300-and-MIcrobee-games` (public, branch `main`), project folder `VZURID/`. Other games live in sibling folders; do not touch them. Commit messages in the repo are plain descriptions of the change.
