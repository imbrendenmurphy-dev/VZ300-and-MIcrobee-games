# OVERRIDE
### v0.7 · five ships, 33 decks, 23 droid types · VIBED BY BPM 2026

## What's new in v0.7: the alert level
- **The ship's alert level**, after Paradroid's alert status. Every droid you destroy or take
  over heats the alert up (three quick kills make it red), and it cools a little every second
  (red back to green in about 15 seconds). The rule under the HUD shows it: green, yellow or red,
  with YELLOW ALERT or RED ALERT on the HUD as it rises. While it lasts, yellow alert pays 25
  points a second and red alert 75, so fighting fast is worth it. It resets for each ship.
- **Room to grow**: the HUD code moved out of the main program into free RAM above the variables
  ($B1F0, loaded from `OVCOM.DAT` at boot), taking the main program from 20 bytes free to 490.

## v0.6: progression without frustration
- **You keep your droid between ships.** You used to arrive on every new ship as the bare probe,
  often in front of armed droids. Now you arrive in the body you finished the last ship in, with
  its energy refilled. (A new game, or a continue, still starts as the probe.)
- **A spare probe for every ship secured**, up to five (the HUD shows four spares). The Ship
  Secured card says so: BONUS 5000 +1 PROBE.
- **Continue.** After game over (and your initials, if you made the table), CONTINUE? counts down
  from 9: fire takes you back to the start of the ship you reached with three probes and the
  score from zero, so the high-score table stays honest. The game-over screen also shows how far
  you got (REACHED SHIP 3 OF 5).
- **Gentler arrival decks.** You land on each ship's top deck, so those decks shouldn't be the
  ones that kill you on the way in. They are now the easy rooms of each ship:
  - Halcyon's Observatory: a sentry (461) swapped for a steward (218);
  - Grindstone's Bridge: 341, 263, 461 instead of 461, 524, 341;
  - Leviathan's Command: 632, 587, 461, 218 instead of the Prefect (908) and a Marshal (817)
    at the door. The Prefect now waits only in the Core with the Overmind.
- **The sound setting outside play**: the title's bottom line takes turns between PRESS FIRE TO
  START and the current output (C  SOUND: SPEAKER / BOTH / TAPE OUT), and pressing C there
  shows the new setting straight away.
- **The ending shows the whole fleet**: THE FLEET IS FREE over all five ships' silhouettes,
  before the credits.
- **Fixed: the attract demo could sit in the lift for the whole demo.** The lift autopilot only
  acted when a frame counter was a multiple of 64, but the lift loop steps it by 2, so on an odd
  count it never chose a deck. It now rides to the next deck that still has droids.

- **Fixed: losing a link duel as the bare probe left the game running with no probe.** The duel
  flagged your death, then jumped back to the top of the frame loop, which clears the event. The
  same jump also lost DECK CLEARED when you won a duel against a deck's last droid. Both now carry
  on into the loop without clearing it, and the loop now checks every frame for a dead player
  rather than only when an event is waiting.
- **Fixed: the briefing's LINK line was 33 characters**, one more than fits. The 33rd (a comma)
  wrapped into the next pixel row at the left edge and drew over the L of LINK. The build now
  refuses any briefing line over 32 characters.
- **Smoother, in-tune music in play.** With only one interrupt a field, the ring's samples were
  played only in the screen-copy loops and the idle wait: every frame had a 13-20 ms stretch (the
  game logic, sprites and HUD) with no sound at all. The tune kept stopping and catching up, its
  tempo followed the frame rate, and because fewer samples were played than the tunes were pitched
  for, everything ran about a third flat. Now:
  - every droid, shot, door and sprite, every tile row of a deck column being drawn, every fourth
    tile lookup and HUD character, and two points in the frame loop play one sample, and the
    mixer plays one for every eight it makes. The longest silent gap fell from about 20 ms to 3;
  - the tune steps by fields (25 a second), not frames, so a slow frame no longer drags it;
  - the tunes are pitched for the rate actually measured in play (about 60 samples a field);
  - the ring keeps 250 samples queued (three fields) instead of 232.

  The sample sites still aren't evenly spaced (the field with the screen copy plays more than the
  field with the game logic), so there is some roughness left, but no more gaps or drift.

- **Link duels rebalanced.** They were hardest exactly where you need them: as the bare probe, a
  good player won about half the time against a class 1 droid, 31% against class 2 and 22% against
  class 3 (a model of the duel with its real rules and AI, against a simulated player with human
  reaction times). Now:
  - you get 7 + your class pulses (was 5 + class); the droid gets 1 + 1.5 x its class (was 4 +
    class), so a low droid is outgunned and a high one still isn't;
  - nodes you take stay locked longer than the droid's (70 steps against 45);
  - the droid thinks more slowly (every 30 - 2 x class steps, was 22);
  - only class 5 and up keep a pulse back to steal a node in the last two seconds;
  - holding up or down repeats (12 lanes a second), and you get eight seconds to pick a side
    (was under three), with the prompt explaining what to do;
  - a new attract page, THE LINK DUEL, explains the rules.

  In the model, a novice player as the probe now wins about 97% against class 1, 87% against
  class 2, 84% against class 3 and 52% against class 4. A body two or three classes up is about
  even, and the class 9s stay hard (a class 5 body wins about a third of the time). The model is
  	ools/duelsim.py.
- **You take half damage** from shots and collisions (rounded up), so a body lasts twice as long.
- **Fixed: winning a duel played the LINK FAILED jingle.** It now plays the bright fanfare.
- **HUD**: the energy bar's empty part is now a dotted track, so a full bar visibly reaches the
  end (it is energy against that body's maximum). Spare probes now show as a count and a little probe ("2" and a ringed
  red eye) between the name and the score; the old yellow pips sat under the score and ran into it.
- **The intro ends with a cut to empty space** instead of a full-screen yellow flash.
- **The briefing pages sit one pixel in from the left edge.**

How the balance was judged: the autopilot was meant to play each ship for ten minutes, but it is
far too cautious to measure difficulty (two droids in ten minutes). Instead each deck got a threat
score from its droids' weapons, aggression and energy. The ship totals run 343, 364, 732, 992 and
1400, and the spikes were the arrival decks above (Leviathan's Command was the third-hardest deck
in the game, at 187).

## v0.5: more variety and more music- **Two new ships**, and the campaign is now five ships long:
  1. **SV CORMORANT**, the freighter (classes 1-4)
  2. **LV ARCADIA**, a cruise liner: Sun Deck, Promenade, Staterooms, Casino, Theatre, Laundry,
     Engines (classes 1-5) *(new)*
  3. **MV HALCYON**, the science vessel (classes 1-6)
  4. **HV GRINDSTONE**, an ore hauler: Bridge, Crew Mess, Ore Bay, Drill Deck, Refinery, Smelter,
     Engines (classes 1-7) *(new)*
  5. **CV LEVIATHAN**, the warship, with the Overmind in its Core (classes 1-9)
- **Each ship has its own look.** The ship file carries its own floor and wall tiles: diamond carpet
  and gold-trimmed walls on the liner, a lab grid on the Halcyon, tread plate and red rust-plated
  walls on the Grindstone, heavy plates with red-edged armour on the Leviathan. The ship cards show
  each ship's own silhouette (liner, saucer-hulled lab ship, ore hauler with pods and a crane,
  armoured wedge with turrets) instead of the freighter every time.
- **New deck layouts.** Besides the usual rooms off a spine corridor, decks can now be:
  - **cells**: rows of small cabins (Quarters, Staterooms, Sickbay, Brig, Crew Mess, Barracks);
  - **halls**: a few big halls with rows of machinery (Machine Shop, Promenade, Casino, Labs,
    Drill Deck, Smelter, Armoury, Foundry);
  - **bays**: an open bay right across the middle of the deck, the corridor walls gone, cargo
    stacked about and hazard plating round the edge (Cargo Hold, Theatre, Stores, Ore Bay, Hangar).
- **Four new droids and a new weapon, the SCATTER GUN** (three shots in a fan, short range):
  - 129 VALET (class 1): quick liner service unit, unarmed;
  - 341 DRILLER (class 3): slow mining unit with a scatter gun;
  - 479 FOREMAN (class 4): tough mine boss with a scatter gun;
  - 741 RAVAGER (class 7): fast boarding droid with a scatter gun.
- **Every class has its own body shape**: a low dome and skirt for class 1, an aerial and wheels for
  class 2, twin lamps and heavy feet for 3, a broad dome on many legs for 4, a sensor eye for 5,
  shoulder spikes for 6, antlers and tracks for 7, an armoured cowl for 8, and a crown and full
  tread for 9. You can tell a droid's class at a glance before reading its number.
- **Ten in-game tunes instead of three.** Each ship has its own tune, and its bottom deck (the
  engines, reactor or core) has a second, busier engine-room tune:
  - Cormorant: D minor, slow and uneasy / engine room: D minor, busy sixteenths;
  - Arcadia: a breezy F major lounge tune over a walking bass / engine room: A minor arpeggios;
  - Halcyon: E minor, pulsing / reactor: E minor arpeggios;
  - Grindstone: G minor, heavy and industrial / engine room: C minor;
  - Leviathan: C minor, driving / the Core: a fast A minor finale for the fight with the Overmind.

  The tunes travel in the ship files (`OVn.DAT`) and load into a buffer in upper bank 1, so adding
  them cost no resident memory; moving the old three out paid for the new droids.
- **New front-end music**: the lift and console have their own calm three-voice tune, and a duel
  against a heavy droid (class 7 and up) gets a faster, harder duel tune.
- **Cassette out as a sound option.** C cycles the sound output: SPEAKER, BOTH (speaker and the
  cassette socket) and TAPE OUT (cassette socket only, the speaker silent). Plug the cassette
  output into an amplifier or powered speakers for much better sound than the built-in piezo. The
  cassette port is a 2-bit output, so the voices are mixed as levels rather than just OR-ed: in play
  the bass drives the high bit and the lead the low bit; in the front end voices 1-2 drive the high
  bit and voice 3 the low bit, and effects take both. In play the HUD shows the new setting; it
  applies everywhere, and C doesn't count as "any key" on the attract pages.
- **Fixed**: the display font's M read as an H. Two deck-generator edge cases (a side door squeezed
  against the tapered hull, a door whose approach the hull cut off) are now checked for.
- Copy **all 41 files** from `release/`: there are new ship and deck files (`OV4*.DAT`,
  `OV5*.DAT`), and every `OVn.DAT` changed.

## v0.4: fixes and a new look for the info screens
- **Fixed: dying could leave you with no probe and no control.** The game handles one event a frame,
  and your death could be overwritten in the same frame, either by a link touch or by DECK CLEARED
  when the last droid went down with you. `touch_player` also returned a stale carry flag for a dead
  player, so a droid could "touch" a corpse and start a link duel. Now a dead player always takes
  priority, a dead probe can't be touched, and DECK CLEARED is re-checked after you respawn.
- **Fixed: the title's scrolling ticker overlapped the high score.** HI now has its own row, and the
  ticker runs in a framed band below it. The ticker also scrolls smoothly, a pixel a field, instead
  of jumping a whole character at a time.
- **A display font**: a chunky 6×8 sci-fi face with a yellow-over-green two-tone fill and a red drop
  shadow (red for alerts, green for system screens), used for every heading. It replaces the
  doubled-up 3×5 font.
- **Backdrops**: a circuit-board grid (dotted traces with lit segments and yellow nodes), a starfield,
  and red corner brackets, behind the briefing, droid files, high scores, ship cards, game over,
  ending, lift and console. Headings sit on red-ruled bars, and the tables in framed panels.
- **The lift's ship map**: every deck is a framed hull section, lit green with yellow windows while
  droids remain, dark once cleared, and bright yellow when selected. The lift shaft is a red and
  yellow ladder with a blinking car, and a yellow arrow marks your deck. The status line shows the
  deck's name and how many droids are left ("2 QUARTERS 6 LEFT"), taking turns with the controls.
- **The link duel's new look**: the droids sit in a framed header panel with their charge cells, the
  seconds left and a timer bar that turns red in the last three seconds. The node column is framed
  as a core. Amplifier gates show as yellow diamonds, reversers as green crosses. Your cursor is an
  arrow at the lane's mouth. A tug-of-war meter along the bottom shows who holds how many nodes, and
  the verdict comes up in the display font. Also fixed: sparks left trails across broken lanes.
- **Console**: the deck name and DROID FILES headings in the display font, and each droid's file and
  its description in panels.
- **Memory**: the title, attract pages, ship cards, game over, ending and their music moved into an
  overlay, `OVTTL.DAT` (7K). It loads into low bank 3 (where the deck's scroll buffer lives in play)
  at the start of each attract cycle and for each card, freeing 4K of the front end for the font,
  the backdrops and the new screens. It replaces `OVATT.DAT`.
- **Front-end screen updates** are now round-robin: still at most 22 rows a field (no snow), but a
  screen that redraws its top every frame can no longer starve its bottom rows.
- Tested in the shared VZonPC emulator (`VZonPC\vzemu.exe`), including `DOSSCRIBBLE=1` runs.

## v0.3: intro cinematic and a soundtrack in play
- **An intro cinematic opens every attract cycle** (`OVATT.DAT`, about 16 seconds; fire skips it):
  - a drifting starfield, with "2391. THE OUTER BELT." typed in;
  - the Kestrel freighter glides in from the right;
  - THE KESTREL FREIGHTERS / HAVE GONE DARK;
  - **red alert**: the palette flashes between the colour sets with a siren, under
    A ROGUE MIND RULES / EVERY DROID ABOARD;
  - the probe streaks from the corner to the freighter's hull (ONE PROBE. ONE CHANCE.);
  - a flash into the title.

  It has its own three-voice tune (bells, a pad and a heartbeat kick). The file loads into low
  bank 3, where the game's ring buffer lives between games, so it is read from the card at the
  start of each cycle. If it's missing, the attract sequence simply starts at the title.
- **A two-channel soundtrack during play**: bass on speaker line 5 and lead on line 0, with a tune
  for each ship:
  - **SV CORMORANT**: D minor, slow and uneasy;
  - **MV HALCYON**: E minor, pulsing;
  - **CV LEVIATHAN**: C minor, driving.

  Effects take the lead channel while they play. Loud ones (explosions, hits) take both lines and
  briefly mute the bass. N switches the music off and leaves the effects on.
- **How it works**: all sound in play now comes from a 256-sample ring. Once a frame, a mixer in
  upper bank 1 steps the tune and fills the ring about 232 samples ahead (132 T a sample, about
  2.5% of the CPU). Every sample site just plays the next byte: the interrupt copy (every four
  chunks), the window copy (every row, padded) and the idle wait, all about 875 T apart. The
  frame rate went *up*: in the emulator, 92% of play frames now hold 25 fps on ship 1, against 85%
  before, because the sites no longer work out samples themselves.
- **A briefing tune** (A minor, three voices) for the briefing, droid-file and high-score pages.
  The title theme now plays on the title only.
- **Fixed: the demo linking over and over.** After a duel, the droid was still touching you with
  fire still held, so a new duel began at once. Link mode now ends with the duel, a droid you have
  just duelled waits a moment before it can be linked again, and duels count towards the demo's
  length. The attract cycle is now about 70 seconds: intro, title, briefing, files, scores, demo,
  scores.
- Recordings from the emulator are in `screenshots/`: `attract_intro_and_title.wav`,
  `attract_briefing.wav`, `ingame_cormorant.wav` and `ingame_leviathan.wav`.

## What's new in v0.2 (polish)
- **The LINK PROBE has its own look**: a ringed red eye with four feelers, instead of a droid
  marked 000.
- **N switches the music on and off** anywhere. It doesn't count as "any key", so it won't skip an
  attract page.
- **LOW ENERGY**: the HUD warns once when your body drops below a quarter of its energy.
- **The link duel shows YOU** beside the timer on your side. Charge pips are capped at six so the
  label fits.
- **Console map**: droids show as blinking 2×2 dots, and you as a yellow / green dot.
- **The title draws PRESS FIRE TO START at once** (it used to appear only on the first blink).
- **More varied decks**: some rooms have studded or grated floors, and bigger rooms get an island of
  computer banks, reactor cores or cargo, kept only if every part of the deck can still be reached.
- **Front-end screens update at most 22 rows a field**, so their video RAM writes stay inside the
  sync gap and the music barely stops.
Dick Smith VZ300 · BennVenn SD + 128K · Mode 1 (128×64, 4 colours) · all Z80

An original top-down droid-transfer action game in the Paradroid tradition, written from scratch for
the VZ300. A rogue ship mind, the OVERMIND, has taken over every droid on the five ships of the
Kestrel Line. You are the LINK PROBE (unit 000), a small unarmed unit that can take over any droid it
touches. Shoot droids, or link into them and win the circuit duel to take their bodies. Clear every
deck of every ship.

The name, ships, droids, numbers, art, board design and music are all new. The genre's ideas are
kept: numbered droid classes, link duels, lifts between decks, consoles, and decks going dark when
cleared.

## Running it
Copy **all 41 files** from `release/` to the root of the SD card: `OVERRIDE.VZ`, `OVCOM.DAT`, `OVTTL.DAT` (the intro, title and cards),
`OV1.DAT`-`OV5.DAT` (ship headers, themes, tunes) and `OV1D0.DAT`-`OV5D5.DAT` (one file per deck). Load
`OVERRIDE.VZ` like any other .VZ. It loads at $8000 (10.6K), loads `OVCOM.DAT` at boot, and reads each
deck from the card when you ride a lift to it (well under a second).

| File | Contents | Loaded into |
|---|---|---|
| `OVERRIDE.VZ` | the engine: renderer, droids, player, shots, HUD, SD loader, autopilot | main RAM $8000 |
| `OVCOM.DAT` | the screen-copy code, tiles (normal and lights-out), droid images, explosions; and the front end: title, attract, link duel, lift, console, cards, music and songs, title picture | upper bank 1 $CA00 / upper bank 0 $B800 |
| `OVn.DAT` | ship n: name, deck sizes, lift shafts, droid counts; its tiles, its two tunes, its silhouette | main RAM / upper bank 1 / upper bank 0 |
| `OVnDd.DAT` | deck d of ship n: map, deck info, droid spawn list, waypoint graph | upper bank 1 / main RAM |

If the expansion is missing you get `NEEDS BENNVENN SD + 128K RAM`. If a file is missing you get
`CAN'T LOAD OV*.DAT FILES`. If the files come from different builds you get
`OV*.DAT FILES DON'T MATCH`, so always copy all the files together.

## Controls
| | Keyboard | Joystick (either) |
|---|---|---|
| Move (8 ways, with momentum) | Q A O P (or Z X for left/right) | stick |
| Shoot where you face | SPACE or M (tap or hold) | fire |
| Link mode | hold fire and stand still for half a second (your droid pulses red), then touch a droid | |
| Lift | fire while standing on a lift pad | |
| Console | push into a terminal | |
| Pause | RETURN | |
| Music on/off | N | |
| Sound output: speaker / both / cassette out | C | |
| Link duel | up/down choose a lane, fire sends a pulse; left/right picks your side at the start | |

## Playing
- **Droids**: each droid has a three-digit number, and the first digit is its class (1-9). Higher
  classes are tougher, faster, better armed and harder to take over. Hostile droids are red with
  yellow numbers. Yours is yellow with blue numbers.
- **Linking**: touching a droid in link mode starts the link duel. Win it and you take that droid's
  body, its weapon and its energy, and the body you were using burns out. Lose it and your current
  body is destroyed (as the bare probe, you lose a life). A tie is a deadlock and nothing changes.
- **Burnout**: a borrowed body wears out slowly (faster for higher classes), so keep moving up. The
  bare probe never burns out but has no gun.
- **Energizers** (the red and yellow coils) recharge the body you're in while you stand on them.
- **Lifts** show the ship in side view: ride the shaft to any deck it serves. Cleared decks show
  as blue.
- **Consoles** show the deck map with every droid on it, then the droid files for every class up
  to your own.
- **Deck cleared**: when the last droid on a deck goes, the lights go out (the floor turns blue) and
  you score a 1,000-point bonus. Clear every deck for SHIP SECURED (a 5,000 bonus and a spare probe), then the next
  ship loads, and you keep the droid you're in. Free all five ships for the ending.
- Three probes (lives), up to five. After game over you can continue from the ship you reached. Scores: 125 points for a class 1 droid, up to 725 for class 9.

### The link duel
Twelve lanes on each side run from the edge to a central column of twelve nodes, which start split
6-6. Move to a lane and fire to send a pulse down it. When the pulse arrives, its node turns your
colour and **locks** for a moment (a solid node is locked; a striped one can be taken). Lanes can be:
- **plain**
- **broken** (the wire stops halfway, with a cap)
- **forked** (a riser feeds two nodes)
- **boosted** (a yellow and blue block: locks for twice as long)
- **reversed** (a green block: hands the node to the *other* side, so avoid it)

You get 7 + your class pulses and the droid gets 1 + 1.5 x its class (rounded down), and your nodes stay locked longer than the droid's. After ten seconds,
whoever holds more nodes wins. The droid's AI thinks faster the higher its class, and from class 5 up it
keeps a pulse back to steal a node in the last two seconds. You have eight seconds to pick a side, and
holding up or down moves the cursor quickly. Roughly: the bare probe can take classes 1-3, and a body
about two classes above your own is an even fight. The attract sequence has a page explaining the duel.

## The cast
| No. | Name | Class | Weapon |
|---|---|---|---|
| 000 | LINK PROBE | 0 | none |
| 104 | DUSTER | 1 | none |
| 129 | VALET | 1 | none (quick) |
| 152 | COURIER | 1 | none |
| 218 | STEWARD | 2 | arc zapper |
| 263 | WELDER | 2 | arc zapper |
| 307 | PORTER | 3 | none (heavy) |
| 341 | DRILLER | 3 | scatter gun (slow) |
| 355 | TECHNICIAN | 3 | laser |
| 408 | MEDIC | 4 | arc zapper |
| 461 | SENTRY | 4 | laser |
| 479 | FOREMAN | 4 | scatter gun |
| 524 | SURVEYOR | 5 | laser (fast) |
| 587 | WARDEN | 5 | twin laser |
| 632 | ENFORCER | 6 | twin laser |
| 668 | BULWARK | 6 | laser (very tough) |
| 705 | TROOPER | 7 | pulse gun |
| 741 | RAVAGER | 7 | scatter gun (fast) |
| 773 | HUNTER | 7 | pulse gun (fast, hunts you) |
| 817 | MARSHAL | 8 | plasma cannon |
| 856 | DREADNOUGHT | 8 | plasma cannon (slow, huge energy) |
| 908 | PREFECT | 9 | plasma cannon |
| 960 | OVERMIND | 9 | plasma cannon (the final droid, in the CORE of the Leviathan) |

## The ships
1. **SV CORMORANT**: Bridge, Quarters, Galley, Cargo Hold, Machine Shop, Engines (classes 1-4)
2. **LV ARCADIA**: Sun Deck, Promenade, Staterooms, Casino, Theatre, Laundry, Engines (classes 1-5)
3. **MV HALCYON**: Observatory, Bridge, Sickbay, Labs, Brig, Stores, Reactor (classes 1-6)
4. **HV GRINDSTONE**: Bridge, Crew Mess, Ore Bay, Drill Deck, Refinery, Smelter, Engines (classes 1-7)
5. **CV LEVIATHAN**: Command, Armoury, Barracks, Hangar, Foundry, Core (classes 1-9)

## Attract sequence
Leave the title alone and the game shows itself off:
1. The title: the OVERRIDE logo, a parade of droids, the high score, a scrolling ticker and the
   three-voice title theme ("Override", A minor, 150 bpm, 30 bars with bass, lead and drums).
2. A typewriter briefing, then the controls.
3. Three pages of droid files.
4. The high-score table.
5. **The AI demo**: the autopilot plays the real game for about 45 seconds. It finds the nearest
   droid, plans a route over the deck's waypoint graph (BFS), shoots weaker droids and links into
   stronger ones, plays the link duel (choosing a side and firing pulses by itself) and rides the
   lifts. Each demo visits the next ship.
6. The high scores again, then back to the title. Fire starts a game from any of these screens.

## Engine
- **Display**: mode 1, colour set 0. Rows 0-9 are the HUD; rows 10-63 show the deck as 16×9 tiles
  of 8×6 pixels.
- **Four-phase ring buffer** (low bank 3, 8K): the deck around the camera is kept pre-rendered at
  all four pixel phases, 64 rows × 32 byte columns each. Moving the camera only renders the new byte
  column (about 18K T) or pixel row (about 8K T), so scrolling is pixel smooth in all eight
  directions. Each frame the right phase is copied into the back buffer with an LDI chain
  (two runs a row for the wrap).
- **Back buffer** (upper bank 1): 40-byte rows with 4 guard bytes on each side, so sprites need no
  horizontal clipping. The IM 2 field interrupt copies it to video RAM with an unrolled stack copy
  (12.75 T a byte), starting at field sync and outrunning the beam. The HUD rows are copied only
  when they change.
- **Sprites**: 13×8 droids with the number drawn in a 3×5 font. They are pre-shifted into a
  4-phase (mask, data) cache when you enter a deck, and drawn with a POP blitter. A silhouette mode
  gives the hit flash and the link-mode pulse.
- **Droid AI**: each deck has a waypoint graph (made by the deck generator and checked for clear
  2×2 paths). Droids wander it, hunters (aggression 3) pick the waypoint nearest you, and armed
  droids check line of sight (one droid a frame, a 16-step ray march) and fire in 8 directions.
- **Player**: momentum movement in 16ths of a pixel, a 9-point box test, and corner-sliding so you
  slip through doorways.
- **Doors** slide open in two steps when anything comes near and close behind it; only the changed
  tiles are re-rendered into the ring.
- **Sound**: in play, one effects voice (pitch, volume, noise) sampled about every 800 T. It
  plays during the window copy, the idle wait and, through a table built once a frame, the
  interrupt's screen copy. The front end uses the three-voice pulse player from Dracula's Castle II
  (211 T a sample, decaying pulse widths, noise drums) in each field's idle time. Screens there
  update only their changed rows, at most 22 rows a field, so the music barely stops.
- **Speed**: in the emulator about 85% of play frames take two fields (25 fps) and the rest three.

### Memory map (mapping 7 = low bank 3 + upper bank 1)
| Range | Contents |
|---|---|
| $4000-$5FFF low bank 3 | ring buffer, 4 phases × 2K |
| $6000-$67FF low bank 3 | pre-shifted droid sprites (8 slots) |
| $7000-$77FF | video RAM |
| $7800-$7BFF | left alone (ROM/DOS system area) |
| $7C00-$7D7F / $7D80-$7FFF | IM 2 table / stack |
| $8000-$AA15 | main code (490 bytes free) |
| $AC00-$B4FF | variables, droid and shot tables, ship and deck info |
| $B1F0-$B468 | play-only code: the HUD and the alert level (from `OVCOM.DAT`) |
| $B500 / $B600-$B7FF | y/6 table / SD bounce buffer |
| upper 1 $B800-$C1FF | back buffer (64 × 40) |
| upper 1 $C200-$C9FF | deck map (64 × 32 tiles) |
| upper 1 $CA00-$F262 | screen copy, tilesets (this ship's theme), explosion, droid images, names, game-music player |
| upper 1 $F263-$F582 | this ship's two tunes (from `OVn.DAT`) |
| upper 1 $F600-$F87F | the deck's waypoints |
| upper 0 $B800-$DDCA | front end (mapping 3): music player, display font, backdrops, duel, lift, console |
| low bank 3 $4000-$5DC7 | between decks only: the overlay `OVTTL.DAT` (intro, title, attract, cards, their music) |
| upper 0 $E560-$E7FF | this ship's silhouette for the cards (4 phases, from `OVn.DAT`) |
| upper 0 $E800-$EFFF | front-end screen buffer |
| upper 0 $F000-$FFFF | DOS stack, sector buffer, DOS RAM (never touched) |

SD loading uses the 13 Ghosts / Dracula's Castle II / Zephyr Zone DOS calls ($5F00/$5F03/$5F09),
with the DOS mapping only during calls, interrupts off and IM 1, and a 2K DOS stack in upper bank 0.
The file format is chunks (`db map, dw dest, dw length, data`), each with the build id.

## Verification
**Only run in emulators so far, not yet on a real VZ300.** From v0.4 the tests run in the shared VZonPC emulator (`C:\Users\Owner\Documents\VZonPC\vzemu.exe`, same script language); `emu/` holds the game's original harness.
- The harness is `emu/vzemu.exe`, a C# rewrite of the vzemu.c harness used by the other VZ games,
  built with the `csc` that ships with Windows. It has its own Z80 core, the BennVenn banking and DOS
  traps, field-sync INT, a snow counter, PNG screenshots, WAV capture and a profiler. As a check, it
  runs the released Zephyr Zone correctly.
- Tested:
  - the whole attract loop several times over (title, briefing, files, scores, demos on ships 1 and 2
    with lift rides and link duels);
  - a real game from the title (ship card, movement, link mode, the lift, a forced link duel played
    with the keys);
  - the console;
  - deck cleared (lights out) and ship secured, then loading ship 2;
  - an 18,000-frame random-input soak with random power-on RAM: no crash and no stack creep.
  - v0.5, in VZonPC: every ship's card, first deck and bottom deck (checking the right tune plays on
    each), Grindstone secured and the Leviathan loading after it with its own tiles and tunes, the
    lift and console tune, the heavy-droid duel tune against the 908, scatter-gun droids firing
    three-shot fans, 15,000-frame random soaks on the Arcadia and the Halcyon, a 9,000-frame soak in
    the Ore Bay, and the attract loop with `DOSSCRIBBLE=1`: no crashes, lowest stack $7FD2.
- The title theme was recorded to `screenshots/title_theme.wav`; its pitch checks out (the bass
  measures A2).

**Please check on hardware**:
- Snow. In play, the interrupt's copy ends about 118 lines after field sync. Zephyr Zone's hardware
  reports suggest the picture starts around line 120, and Galahxy found no snow from writes during
  the picture, but please look.
- How the effects and the three-voice title music sound through the speaker.
- Loading every deck file from the card.
- The joystick.

## Building
```
py tools/build.py        # -> build/sd/OVERRIDE.VZ, OVCOM.DAT, OV1-5.DAT, OV1D0..OV5D5.DAT
py tools/fixjr.py src/main.asm   # (if an edit pushes a JR out of range)
C:\Windows\Microsoft.NET\Framework64\v4.0.30319\csc.exe /optimize+ /out:emu\vzemu.exe /r:System.Drawing.dll emu\Z80.cs emu\VzEmu.cs emu\Font6847.cs
emu\vzemu.exe script.txt   # scripted runs: vz, sd, frames, tap, down/up, screen, wav, rand, crash, snow, tmark, prof ...
```
You need Python 3 with Pillow. The assembler is `tools/zasm.py` (from Dracula's Castle II / Zephyr
Zone). Decks are generated from seeds in `tools/ships.py` (hull, spine corridor, rooms, doors, props,
consoles, energizers, lifts, waypoint graph, connectivity checks). `py tools/ships.py` writes a
preview PNG of every deck to `build/`. The music is in `tools/music.py`, the roster in
`tools/roster.py`, and the art in `tools/gfx.py` and `tools/fedata.py`.
