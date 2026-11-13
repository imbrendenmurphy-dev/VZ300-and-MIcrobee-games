# MAX Q — Stage 5: the game (v0.7)
*VIBED BY BPM 2026*

## How it plays

- **Attract mode:** the title card (with the colour-set split), then the best-times card, then a demo race with the rivals. It loops until someone presses **SPACE or joystick fire**.
- **Race:** a "GET READY" banner, a 3-2-1-GO countdown with beeps, then **3 laps** against **3 rival hover craft**. The HUD shows speed, lap, position, race time, a shield bar and the frame rate (F).
- **Boost pads:** glowing yellow bands across the track, 4 per lap. Driving over one lifts the speed limit from 110 to 150 for about 1.4 s. The rivals use them too.
- **Energy shield (forgiving):** scraping a barrier costs 2 and bumping a rival costs 4, out of 64. The shield recharges slowly. When it runs out you **never** blow up: SHIELD DOWN slows the craft for 2.4 s, then it carries on with a third of the shield.
- **Rivals:** each one has its own speed and lane, and follows the racing line. When far ahead they ease off, and when far behind they push harder, so the pack stays close. Running into one costs you speed; one running into you gives you a shove.
- **Finish:** a lap of honour on autopilot, then the results card (position, time, NEW RECORD TIME!), then back to attract mode. The best 4 times are kept until the machine is switched off.
- **Sound:** short beeper effects for the countdown, GO, boost (rising warble), bumps (crunch), each new lap, shield down (falling) and the win fanfare. Each one is a burst of about 1,600 T at the end of the field interrupt.

## Measured (cycle-exact emulator)

| | Fields per frame | fps |
|---|---|---|
| v0.6, track only | 4.43 | 11.3 |
| v0.7, with rivals, HUD and sound, half-rate rows on | 4.77 | 10.5 |
| v0.7, half-rate rows off | 5.25 | 9.5 |

An automated race (the autopilot driving, started by a scripted SPACE press) ran through countdown → 3 laps → finish → results → attract mode in the emulator, with a 1:10 race time. The renderer is still byte-for-byte identical to the reference, boost pads included (17 of 17 test frames).

## Speed work in this stage

- The frame copy is now a loop: 2.7 KB of memory freed for the game code, at a cost of about 6,000 T per frame.
- **Plain-sky rows:** the rows between the HUD and the skyline that hold only open sky are no longer recomposed or recopied while nothing has drawn on them (+0.6 fps).
- The HUD redraws a line only when its text changes, and shows race time in whole seconds.
- Rivals work out their racing line once per section instead of every field.
- The sound bursts have a fixed budget.

The game logic, rivals, HUD and sound together cost about 0.35 fields per frame, so the race runs at about 10.5 fps against 11.3 for the bare track.

---

# v0.8 — hovercraft

- **New craft:** hand-tidied pixel art, drawn from behind and above.
  - **Player** (yellow body, dark canopy, red thruster): 7 views from hard left to hard right, yawing and banking into the turn, plus nose-up (climbs) and nose-down (dips). It hovers 1 px above a separate dithered shadow and bobs gently.
  - **Rivals:** red team (red body, yellow thruster glow) and blue team (dark blue silhouette with a yellow top edge and a red thruster). Each has 5 views, chosen from how far the track bends at the rival's position, so on a curve ahead you see it side-on.
  - **Sizes:** full size up close, a 16×6 version at mid-distance, and a small wedge in team colours far away.
- **Memory:** the sprites live in the BennVenn's **SRAM bank B** (port $37 = 3, mapped at $4000–$67FF), the same way Tiger Gate uses it.
  - Only the left-hand views are stored in the program (1.7 KB). At start-up the game makes the mirror images and all the pre-shifted copies: 7.6 KB in bank B.
  - Every copy was checked byte for byte against the Python art in the emulator (80 of 80).
- **Speed:** 10.5 fps measured in the emulator, the same as v0.7.
