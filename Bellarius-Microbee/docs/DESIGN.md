# BELLARIUS! — design

*A Parodius-style shoot-'em-up for the Microbee Premium Plus. VIBED BY BPM 2026.*

Somebody has stolen all the bells in the world, and the trail leads up to a cloud-top office tower: Head Office. Four unlikely pilots take off to get them back.

A Parodius-style comedy shooter: tight horizontal shooting, a Gradius-style upgrade bar, bells you juggle for points and powers, classical music played far too fast, and bosses that are a joke the first time and a test the second.

## 1. Target machine (verified)

Microbee Technology's Premium Plus spec page lists: Z80 at 3.375 MHz (Z80 mode), 1MB RAM shared with the ColdFire, 32K PCG RAM, 2K colour RAM, 2K attribute RAM, colour TTL and mono composite video, an SD card interface with floppy emulation in Z80 mode, an optional real floppy interface, and the standard DB15 parallel port.

| Area | Choice | Status |
|---|---|---|
| CPU | Z80 3.375 MHz only (the ColdFire is not used) | spec page |
| Display | 40 × 25 cells of 8 × 8 pixels (320 × 200), CRTC table from BPM's MODES40 test, plus the 40-column dot clock (read port 09h with A=1) | first real test showed 4 small pictures without the clock select; fixed, awaiting re-test |
| Colour | 16 colours, ink + paper per cell; colour RAM via port 08h bit 6 | proven |
| PCG | 16 banks × 128 glyphs, bank per cell from attribute RAM | proven |
| RAM | 32 blocks × 32K through port 50h; the game uses about 20 | proven (earlier games) |
| Page flip | two screen pages (000h and 400h), 6545 start address changed in vertical blank | proven at 64×16; used at 40×25 by Kaboomerang |
| Sound | PIO B bit 6 speaker, 2-voice pin-pulse engine in idle time | proven (earlier games) |
| Input | keyboard by 6545 light-pen scan; joystick on PIO A (parallel port) | keyboard proven |
| Storage | DS80 disk image (800K) booted from the SD card; boots to CP/M A>, no shell; `BELLS` runs the loader | proven (BPM loads images from SD) |
| Saving | SAVE.DAT on the same disk: WD2793 sector write to a fixed sector, checked against the directory first | emulator only; needs a real-hardware check through the SD floppy emulation |

## 2. The cast (four pilots + one unlock)

| Pilot | Craft | Handling | MISSILE | DOUBLE | LASER | OPTION |
|---|---|---|---|---|---|---|
| **HONK** the cranky goose | flying bathtub | medium speed, 3 hearts | Bread Rolls: drop and skid along the floor | Feathers: 45° up | the Honk Beam: long piercing beam | ducklings |
| **TRUFFLE** the pig | flying piggy bank | slow, 3 hearts | Coin Drop: up and down | Penny Fling: straight back | Oink Rings: expanding rings | gold coins |
| **BOLT** the wind-up robot | rocket sled | slow, tough, 4 hearts | Nut Bombs: lobbed, burst on impact | Spread: three ways | the Wind-up Key: big piercing boomerang that comes back | cogs |
| **QUEENIE** the Microbee | flying keyboard | fast, small hitbox, 2 hearts | Byte Bugs: homing | Twin: two parallel shots | Dot Matrix: fast short beam | floppy disks |
| **POLLY** the parrot *(unlocked by clearing the game)* | herself | fast, 3 hearts | copies Bolt's bombs | copies Bolt's spread | copies Queenie's beam | notes |

## 3. Systems

### Upgrade bar (capsules)
Red enemies and whole formations drop **capsules**. Each capsule moves the cursor one slot along the bar at the bottom of the screen:

`SPEED  MISSL  DOUBL  LASER  OPTN  SHLD  !?`

Press **X** (or Z/M) to take the lit slot; the bar resets. DOUBLE and LASER replace each other. SPEED goes to 4, OPTION to 2, SHIELD soaks 3 hits. **!?** is a panic button: every ordinary enemy on screen is destroyed and every bullet turns into points — the choice is spending seven capsules on a panic button instead of upgrades. Optional AUTO mode takes upgrades for joystick players.

### Bells
Bubble gum, bouncy balls and other "bell carriers" release a **bell**. Shooting a bell bounces it up (+100 each hit). Every third hit it changes colour, and its colour is what you get when you fly into it:

| Colour | Effect |
|---|---|
| GOLD | points: 500, 1000, 2000, 3000, 5000, 10000 for gold bells in a row, × the juggle multiplier |
| BLUE | MEGAPHONE: all bullets become points, every enemy takes heavy damage |
| GREEN | GIANT: 6 seconds invulnerable; ramming destroys enemies |
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

| # | Stage | Visual gag | Formations | Terrain | Boss | Music |
|---|---|---|---|---|---|---|
| 1 | **THE OFFICE IN THE CLOUDS** | a TEAMWROK poster, fluorescent tubes | paper planes in V's, snapping staplers, dripping mugs | lamps, cubicles, a burping water cooler | **COPYTRON 9000**: spits paper swarms; the crumpled sheets jam it open; flashes TONER LOW, then fires | Eine kleine Nachtmusik, as lift muzak |
| 2 | **CANDY CASTLE** | WARNING: SUGAR RUSH | wrapped sweets, a tooth fairy who steals your bell, popping popcorn, gummy bears | lollipops, candy canes, cupcakes on a cake floor | **THE BIRTHDAY CAKE**: cherry lobs, the cake knife; shoot the candles out (FLAMES OUT!) to hurt it | The Entertainer |
| 3 | **TOY BOX** | Mum's note, letter blocks | toy bees, spring frogs, wind-up mice, biplanes, the toy train (CHOO CHOO!) | blocks, tops, rocking horses, crayons, the train track | **JACK-IN-THE-BOX**: marbles, squashes into its box and BOINGs across the screen, dizzy afterwards | Flight of the Bumblebee |
| 4 | **SPACE OPERA** | THE BELLTONES LIVE IN SPACE, amps to 11 | notes that play the tune when shot, plectrums, cymbals, more cowbell | amp stacks, drums, mic stands | **ONE-MAN BAND**: counts 1, 2, 3, 4 and attacks on the beat; hurt only while it takes a bow | the William Tell gallop |
| 5 | **HEAD OFFICE** | lifts, IN and OUT trays | middle managers, briefcases, memos, red tape, shredders | office blocks, trays, lifts | **THE CEO**: pie charts, the DENIED stamp (hunts your column, then slams), tie unravels for the last phase | Hall of the Mountain King, then Ride of the Valkyries |

Bosses 1–4 share Bach's Toccata in D minor. Title: the Can-can. Ending: the pilots throw a party in the empty boardroom and the CEO's stamp comes down one last time: **APPROVED** (Ode to Joy). Clearing the game unlocks POLLY and the CLEARED star on the title.

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
