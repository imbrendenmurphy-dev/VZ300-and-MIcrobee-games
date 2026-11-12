# SKYLARKIN'! — design

*A fair dinkum shoot-'em-up for the Microbee Premium Plus. VIBED BY BPM 2026.*

"Skylarking" is Aussie for mucking about. Head Office (GLOBAL CONSOLIDATED PAPERWORK PTY LTD) has decided the sky is wasted space and is filling it with an open-plan office park. Four local larrikins take off to stop them.

A Parodius-style comedy shooter: tight horizontal shooting, a Gradius-style upgrade bar, bells you juggle for points and powers, and bosses that are a joke the first time and a test the second.

## 1. Target machine (verified)

Microbee Technology's Premium Plus spec page lists: Z80 at 3.375 MHz (Z80 mode), 1MB RAM shared with the ColdFire, 32K PCG RAM, 2K colour RAM, 2K attribute RAM, colour TTL and mono composite video, an SD card interface with floppy emulation in Z80 mode, an optional real floppy interface, and the standard DB15 parallel port.

| Area | Choice | Status |
|---|---|---|
| CPU | Z80 3.375 MHz only (the ColdFire is not used) | spec page |
| Display | 40 × 25 cells of 8 × 8 pixels (320 × 200), CRTC table from BPM's MODES40 test | proven on BPM's Premium Plus |
| Colour | 16 colours, ink + paper per cell; colour RAM via port 08h bit 6 | proven |
| PCG | 16 banks × 128 glyphs, bank per cell from attribute RAM | proven |
| RAM | 32 blocks × 32K through port 50h; the game uses about 20 | proven (earlier games) |
| Page flip | two screen pages (000h and 400h), 6545 start address changed in vertical blank | proven at 64×16; used at 40×25 by Kaboomerang |
| Sound | PIO B bit 6 speaker, 2-voice pin-pulse engine in idle time | proven (earlier games) |
| Input | keyboard by 6545 light-pen scan; joystick on PIO A (parallel port) | keyboard proven |
| Storage | DS80 disk image (800K) booted from the SD card; boots to CP/M A>, no shell; `SKYLARK` runs the loader | proven (BPM loads images from SD) |
| Saving | SAVE.DAT on the same disk: WD2793 sector write to a fixed sector, checked against the directory first | emulator only; needs a real-hardware check through the SD floppy emulation |

## 2. The cast (four pilots + one unlock)

| Pilot | Craft | Handling | Shot | MISSILE | DOUBLE | LASER | OPTION |
|---|---|---|---|---|---|---|---|
| **BAZZA** the bin chicken (ibis) | flying wheelie bin | medium speed, 3 hearts | chip | Rotten Banana: drops and skids along the floor | Chicken Bone: 45° up | Stink Line: long piercing beam | Baby Bins |
| **SHEILA** the koala | flying Hills Hoist | slow, wide, 3 hearts | peg | Peg Drop: two ways, up and down | Undies Fling: straight back | Spin Cycle: expanding rings | flying socks |
| **WALLY** the wombat (from KABOOMERANG) | flying ute | slow, tough, 4 hearts | gumnut | Gumnut Bomb: lobbed, bursts on impact | Spread: three ways | Kaboomerang: big piercing boomerang that comes back | hard hats |
| **QUEENIE** the Microbee | rides a Microbee keyboard | fast, small hitbox, 2 hearts | byte | Byte Bugs: homing | Twin: two parallel shots | Dot Matrix: fast short beam | floppy disks |
| **LOCKIE** the lyrebird *(unlocked by clearing the game)* | his own tail | fast, 3 hearts | mimic | mimics Wally's bomb | mimics Wally's spread | mimics Queenie's beam | 2 echo options |

## 3. Systems

### Upgrade bar (capsules)
Red enemies and whole formations drop **capsules**. Each capsule moves the cursor one slot along the bar at the bottom of the screen:

`SPEED  MISSL  DOUBL  LASER  OPTN  SHLD  OI!`

Press **X** (or Z/M) to take the lit slot; the bar resets. DOUBLE and LASER replace each other. SPEED goes to 4, OPTION to 2, SHIELD soaks 3 hits. **OI!** is a shout: every ordinary enemy on screen is destroyed and every bullet turns into points — the choice is spending seven capsules on a panic button instead of upgrades. Optional AUTO mode takes upgrades for joystick players.

### Bells
Party balloons, beach balls and other "bell carriers" release a **bell**. Shooting a bell bounces it up (+100 each hit). Every third hit it changes colour, and its colour is what you get when you fly into it:

| Colour | Effect |
|---|---|
| GOLD | points: 500, 1000, 2000, 3000, 5000, 10000 for gold bells in a row, × the juggle multiplier |
| BLUE | MEGAPHONE: all bullets become points, every enemy takes heavy damage |
| GREEN | BIG BIRD: 6 seconds invulnerable; ramming destroys enemies |
| RED | RAPID: 8 seconds of double fire |
| WHITE | SLOW-MO: 6 seconds of enemies and bullets at half speed |

**Juggling:** after 3 hits a bell is "hot" (it rings and flashes). A hot bell that hits an enemy bonks it and raises the juggle multiplier (×2 … ×5). Steering a hot bell through a wave is a gamble: big multiplier, but your eyes are off the bullets and a dropped bell is gone.

### Forgiving rules (BPM: no insta-death)
- Hearts per life by difficulty: EASY 5, NORMAL 3, HARD 1 (classic one-hit). Pilots adjust ±1.
- A hit flashes the pilot invulnerable for 2 seconds; the shield takes hits first.
- Losing a life: you respawn on the spot with 3 seconds of invulnerability, full hearts, SPEED 1, and three capsules plus your lost options float out to be picked back up.
- Extra life every 50,000. Unlimited continues (score resets, stage kept).

### Readability
- Enemy bullets are white round pellets with the same shape everywhere; enemy bullets are drawn last, over everything, and take the cell's ink.
- The pilot's hitbox is a 4 × 4 pixel core, shown as a dot during invulnerability.
- Every big attack is announced: a flashing WARNING light or sign, a sound, and a pause before it fires.
- Bosses flash white when hit; boss damage is shown on a bar in the HUD.

## 4. Stages

| # | Stage | Visual gag | Formations | Terrain hazards | Boss | Music hook |
|---|---|---|---|---|---|---|
| 1 | **OPEN PLAN** (an office in the sky) | flickering fluorescent tubes, a motivational poster that says TEAMWROK | paper planes in V's, snapping staplers, coffee mugs that drip | ceiling lamps, cubicle walls, a water cooler that burps bubbles | **COPYTRON 9000**: spits paper swarms; shoot the sheets and the crumpled paper jams it, opening its tray (the weak spot); flashes TONER LOW, then fires a toner beam | lift-muzak bossa |
| 2 | **BARBIE BEACH** | NO SHOOTING-'EM-UP BETWEEN THE FLAGS | flip-flopping thongs, seagulls that steal your bell, sizzling snags | sandcastles, waves | **THE GREAT AUSTRALIAN BARBIE**: flips snags in arcs, smoke screen, tong clap | surf twang |
| 3 | **BIG THINGS HIGHWAY** | the Big Banana and Big Pineapple in the distance | fly swarms, bounding roos, emus | road train, road signs | **THE BIG PRAWN**: antenna sweep, cocktail-sauce blobs, tail-flip dash | bush band |
| 4 | **PUB ROCK** | amps stacked to 11 | musical notes that play the stage tune when shot in order, plectrums | amp stacks, mic stands | **ONE-MAN BAND**: counts "1, 2, 3, 4!" then attacks on the beat | pub rock riff |
| 5 | **HEAD OFFICE** | lifts going up, IN and OUT trays | middle managers, briefcases, red tape across the screen | shredders, red tape | **THE CEO**: rubber stamp DENIED (shadow warning before it lands), pie charts that split into wedges, final phase when his tie unravels | boardroom march |

Ending: the larrikins throw an office party in the empty boardroom; the CEO's stamp comes down one last time: **APPROVED**. Then the credits and VIBED BY BPM 2026. Clearing the game unlocks LOCKIE and the **CLEARED** star on the title.

## 5. Front end
Colour / mono choice at start, title with the logo and a scroller, attract demo (the real game flown by an autopilot), hall of fame, pilot select with handling and weapon names, options (difficulty, power-up AUTO/MANUAL, music on/off), pause (H), stage intros, name entry, high scores and settings saved to SAVE.DAT.

| Key | Action |
|---|---|
| arrows or Q A O P | fly |
| SPACE (or joystick fire) | fire (hold for autofire) |
| X, Z or M | take the lit upgrade |
| H | pause; ESC while paused quits |
| S | sound: music + effects / effects / off |

## 6. Engine plan

**Scrolling.** The playfield is rows 1–23 (row 0 is the score line, row 24 the upgrade bar). Terrain lives in up to 12 *strip rows* per stage; the rest is sky. The build tool pre-renders every strip row at four 2-pixel phases into runs of glyph codes, banks and colours. Each frame the renderer copies 40 bytes per row per plane (unrolled LDI) from banked RAM into the hidden page: about 20,000 T-states for 10 strip rows, at 2 pixels per frame (50 pixels a second) with no glyph rebuilding at all. Sky rows are only touched where sprites were.

**Sprites.** Pre-shifted, masked frames composited into a per-page pool of PCG glyphs, from Kaboomerang. Small objects (bullets, shots, beams) use ready-made glyphs: drawn into sky cells by writing a glyph number, and only composited when they overlap something.

**Bosses.** Each boss is a big bitmap pre-shifted four ways, copied straight into a per-page PCG bank (no masking, it sits over the sky); variants for its animation, colour changes for flashes and warnings.

**Budget.** 135,000 T-states per 25 fps frame. Target: 25 fps in ordinary play, no worse than 16.7 fps at peaks. Enemy count and bullet caps are tuned after stage 1 is measured.

## 7. Build order
1. Stage 1 complete with the Copytron, the upgrade bar, bells, all four pilots. **Measure**: frame rate in busy scenes, input-to-screen delay, audio.
2. Stages 2–5, the CEO, the ending.
3. Front end, attract demo, saves, unlock.
4. Release disk, docs, GitHub.
