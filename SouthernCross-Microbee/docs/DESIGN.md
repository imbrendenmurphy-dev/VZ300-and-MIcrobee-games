# SOUTHERN CROSS — design

FS1-style wireframe flight sim for the Microbee Premium Plus. VIBED BY BPM 2026.

## The view
- Top half: 512 × 128 bitmapped 3D window from 512 PCG glyphs, wireframe, double buffered.
- Bottom half: instrument panel built from fixed characters (stage 1 is text; real dials later).
- Target 8–10 fps on the Z80 (FS1 managed about 3). Amber-first, colour option at boot, projection corrected for a 4:3 screen.

## Boot and title
- Boot screen: amber/mono or colour, keyboard or mouse yoke; saved to disk so it only asks once.
- Loading screen: PCG-art trainer banking over the coast, loading bar shaped like a runway.
- Title: large chrome-style logo over a rotating wireframe plane, twinkling Southern Cross stars, scrolling message, title tune.
- Credits: VIBED BY BPM 2026.

## Attract sequence (loops when the title is left alone)
1. Title and logo
2. Live demo flight: take-off, low pass over a landmark, landing ("DEMO" flashing)
3. Aircraft data sheet: spinning wireframe plane, speeds, ceiling, range, typed teletype-style
4. Locale postcards with travel-brochure blurbs
5. Pilot Hall of Fame: best mission scores and landing grades
6. How to fly: animated panel diagram
7. Second demo flight (night landing or dogfight)

## Information screens
- Pilot logbook: hours, landings, best landing grade, medals.
- Mission briefing: route map, typed briefing, weather, fuel, target time.
- Debrief: replay track over the map, landing grade A–F, medal.
- Instrument guide and key reference from the pause menu.

## Quality of life
- Pause menu (resume, restart, map, controls, quit); save/load a flight to disk.
- Reset to final approach or runway threshold.
- Time compression 2× / 4×; optional autopilot (height and heading).
- Landing aid: glide slope indicator and approach lights.
- Outside views: chase plane, tower, look left/right; 30-second instant replay.
- Realism: Easy / Normal / Real (crash forgiveness, unlimited fuel, gentle stalls on Easy).
- Map screen; logbook and settings saved automatically.

## Aircraft
One forgiving single-engine trainer: stall, climb, glide, flaps. Panel: airspeed, altimeter, artificial horizon, compass, vertical speed, RPM, fuel, radio beacon needle. Keyboard, or the serial mouse as the yoke.

## Locales (each a separate disk file, e.g. CORAL.LOC)

**Coral Coast** (home: beaches, islands, lighthouse, reef)
- Island Hopper: supplies to three island strips, short runways, crosswinds
- Search and Rescue: find a boat from radio bearings, circle and report
- Lighthouse Run: low-level slalom through markers along the cliffs
- Storm Front: get home before the weather closes in

**Riverbend** (town, river, bridge, hills, silos)
- First Solo: flying school graduation
- Under the Bridge: fly the river and under the bridge
- Crop Duster: low passes over marked paddocks
- Air Show: loops, rolls and a low pass judged by the crowd
- Night Mail: mail run with only runway lights

**Red Centre** (outback, dirt strips, a giant red rock, cattle stations, dust)
- Flying Doctor: get a doctor to a remote station fast, short dirt strip
- Lost Stockman: search a large area for a smoke signal
- Dust Storm: instruments only
- Fuel Drum: long cross-country, fuel planning matters

**Ace mode**: a campaign over each locale (defend the coast, bomb river bridges, desert dogfights), damage in stages, repairs at friendly airfields.

**Expansion disks** later: e.g. Tasmania (mountains, fog, weather), Great Barrier Reef seaplane pack.

## Ideas taken from VZ Flight (our VZ300 sim)
Proven on the VZ, so they carry straight over:
- **Gates with height bands**: hoops you fly through, each with a floor and ceiling; the HUD's top line shows the next gate, a bearing arrow and the distance. Also "under" gates: pass beneath a bridge deck, below a set height.
- **Forgiving crashes**: a crash puts you back at the last gate passed with +15 seconds on the clock, not back to the start. Easy realism adds a "bounce" on hard landings instead of a crash.
- **Par times, ratings and best scores**: each mission has a par time; finishing gives STUDENT PILOT / FIRST OFFICER / CAPTAIN / ACE AVIATOR, and best times are saved to disk for the Hall of Fame in the attract loop.
- **Free Flight** in every locale, plus short briefings (7 lines of 30 characters) with a bit of real history.
- **Moving ship deck**: a landing target that steams along; also a low pass over its deck.
- **Obstacles and platforms**: collision boxes for bridges, towers and buildings; platforms (decks, pads) you can land on at height.
- **Scenery engine**: each object has a cull distance and a "fine" distance inside which it is drawn at full precision; per-locale colour schemes (sky, ground, grid, water) for the colour option; shorelines as polylines.
- **Look views and map**: look left/right/back and a map view with zoom from the pause menu.
- **Helicopter** as a second aircraft later (hover, pads, "under the bridge" by helicopter).

### Where they go in Southern Cross
- **Riverbend**: First Solo becomes a circuit of gates round the airfield, then a landing; Under the Bridge uses an under-gate (stay below the deck height) followed by a gate slalom down the river; Air Show judges a low pass between two pylon gates.
- **Coral Coast**: Lighthouse Run is a gate course along the cliffs past the lighthouse; a new **Supply Ship** mission lands on (or low-passes) a moving ship's deck; Island Hopper scores each short-strip landing.
- **Red Centre**: a big red rock and a cluster of domes; **Rock Circuit** flies gates around the rock (a no-fly zone over the top costs time, it doesn't crash you); **Domes Hop** threads the gaps between the domes; Flying Doctor ends on a 1 km dirt strip with a cattle-station shed.
- **Harbour City** expansion disk: harbour, arch bridge, opera-house shells, a tower and an airport to the west, as on the VZ.

## Build stages
1. Horizon, panel and flight model as a frame-rate benchmark — **done**
2. Runway, take-off, landing and the landing grade — **done**
3. Locale loader plus the first full locale, Coral Coast — **done (this build)**
4. Missions, briefing and debrief screens, logbook and save/load
5. Title, attract sequence, music and information screens
6. Riverbend, Red Centre and Ace mode
7. Final polish and the SD disk image

## Stage 1 notes
- Emulator frame rates at 3.375 MHz: detail 1 ~15 fps, detail 2 ~8, detail 3 ~5.5.
- Real hardware (BPM, amber monitor): runs and flies; first build showed "--" FPS because the MC146818 isn't ticking on that machine, and ground lines passing close beside the plane could bend up through the sky (one end's x projection saturated while y didn't). Fixed: vertical-blank field counter for FPS and game time; 3D guard-band clip before projection. Checked with an emulator test that renders random flight states and counts ground pixels above the true horizon (0 of 160).
- Speed-up pass 1 (average of five test views 5.54 → 6.30 fps, +14%; detail 1 15 → 19 fps): one-pass 3D clip with margin + 2D edge fix instead of near-plane/guard-band bisection and 2D midpoint search; unrolled set-bit pixel loop (90–100 → ~60 T a pixel incl. setup) with exact long lines; partial buffer clear; inlined negates; unrolled divide and multiply. Near plane now 5 m.
- Measured: on the runway at detail 3 most of the frame is clip/projection maths (≈300k of 380k T for lines), mainly the 8 km grid lines that start behind the aircraft (≈20–25k T each, five clip divisions). Next ideas: clip ground lines against the visible ground footprint on the map (one trapezoid per frame), shorter grid lines built around the aircraft, reuse object vertex clip data, 16-bit table multiply from the 1MB RAM.
- Footprint clip experiment (stage 1, after pass 1): trim each ground line on the map against the patch of ground the camera can see (a trapezoid worked out once per frame), then project only what's left. It drew correctly but ran slower: average 5.47 fps against 6.30, runway view 4.80 against 5.5. The per-frame footprint cost ~40k T, and each ground line still needed ~19k T to clip against it (four edge tests with 16-bit divides) against ~11k T for the improved 3D clip. Kept out of the build; the source is in `docs/experiments/footprint-trim.asm`. Better next bets: draw the grid in screen space from its vanishing points (one projection per grid line end, no clipping), or grid lines built short around the aircraft.
- Speed-up pass 2 (average 6.30 → 7.51 fps, runway 5.50 → 7.34): ground grid drawn in screen space. A ground line seen from height H lies in the plane through the eye with world normal (H, k−px, 0); rotated into view space that normal is the screen line, and the part kept is the ground nearer than ~6.5 km (a line parallel to the horizon). 8×8 multiplies use a quarter-square table. Lines within a pixel of the horizon are skipped (6 of the 10 grid lines when on the runway). Separately, segments whose ends are both plainly in view skip the plane-distance work (~2.3k T each). Checked: pixel-identical scenery, 0 of 120 random flights with ground pixels above the horizon.
- Hardware assumptions (taken from the tested Microbee projects in this repo): port 1Ch b7 premium graphics, b4 attribute RAM, b0–3 PCG bank; port 08h b6 puts colour RAM in the F800 window (low nibble ink, high nibble paper); port 0Bh = 1 during keyboard scans; 6545 status bit 5 (vertical blank) counted as 50 Hz fields for FPS and game time.

## Stage 2 notes
- Landing grade: start at 100 and take off points for sink rate (0 up to 150 ft/min ... 35 over 600), centreline (0 within 2 m ... 20 over 10 m; 40 off the runway), touchdown point (0 between 120 and 450 m from the threshold; short or long costs 8–25), bank, alignment, speed (over 60 kt) and 10 per bounce. A ≥ 90, B ≥ 78, C ≥ 65, D ≥ 50, else E. The message names the biggest fault ("GREASED IT!" when there is none, "NICE LANDING" when every fault is small). Best grade kept for the session (logbook on disk comes in stage 4).
- Forgiving touchdown, from VZ Flight: up to 3.5 m/s sink lands; 3.5–5.5 m/s bounces (nose up 4°, 1/8 speed lost); only beyond that, or a wing tip (bank over 30°) or nose first (over 8° down), crashes. A crash shows the reason and puts you back on final after 3 seconds; R and F still work at any time.
- Approach line: range to the aim point (runway 36: 180 m in; runway 18 is graded too), PAPI as four W/R lights at 2.5°, 2.83°, 3.17° and 3.5°, a glide word, and the centreline offset (left and right as seen by the pilot).
- Take-off report: lift-off speed and the runway used since the roll started.
- Panel: rows 5–6 are now the approach line and a 62-character message line; the frame counter has gone.
- Grid lines moved to 1024 + n×2048 m so none lies on the runway, and lines within 2 pixels of the horizon are skipped.
- Cost: aim markers (one series of 2 lines) and the extra panel rows take the average from 7.51 to 7.20 fps; the runway 18 aim markers were left out because each line series has ~6k T of set-up, even when it's out of view (worth a cheap cull later).
- Tested in the emulator with a scripted pilot: take-off (lift-off at 54 kt after 293 m), a flown approach (grade A, touchdown 171 m in), a firm landing (bounce, then grade D "TOO HARD") and a dive into the ground (crash, back on final 3 s later, repeatedly).

## Stage 3 notes
- **Locale files.** `src/areas.py` describes each area. It defines runways, boxes, outlines and free-form meshes, and builds each object's far set and axis tables automatically. `build.py` assembles every area at LOCBUF (5000h, up to 7A00h). CORAL.LOC is 2K. The HOME field is also built into the program as the fallback.
- **Loading.** `SCROSS` opens the area named on the command line through CP/M (default CORAL.LOC) before disabling interrupts and taking over the video. It checks the 'SC',3 header and falls back to the home field with a message.
- **Coral Coast:**
  - Coral Bay 36/18: 1200 m, with hangar, beach resort and jetty.
  - The coastline from 7 km south to 10 km north, with a headland lighthouse.
  - A cargo ship at anchor and a broken reef line, which only shows at detail 3.
  - Three islands with strips: Turtle Island 09/27 (500 m), Hope Island 36/18 (450 m) and Lizard Island 09/27 (450 m).
- **Runways are data.** Each has a threshold, an axis (N–S or E–W), a length, a half-width and an aim point (180 m on the big runway, length/6 on the strips).
  - **Landing grade:** works out which runway you're on and measures touchdown from that end. The touchdown zone runs from 60 m short of the aim point to a quarter of the runway. Being lined up is checked against the runway's axis.
  - **Approach line:** names the runway you're lined up with ("TURTLE IS 09"). It picks the nearest one ahead within ~27° of its centreline and 45° of its heading.
  - **R, F and N** start on, or on final to, the current airfield. N moves to the next airfield.
- **Scenery table culling.** Each entry has a centre, a cull box, a radius and a minimum detail. It's skipped:
  - if outside the cull box;
  - if behind (ahead distance + radius < 0);
  - if well to the side (|right| > 2 × ahead + 3 × radius), unless the nose is steeply up or down;
  - if it lies flat on the ground and its nearest point is beyond 64 × eye height, which means within ~3 pixels of the horizon;
  - if it's smaller than ~10 pixels (ahead > 24 × radius).

  Under ~21 pixels (ahead > 12 × radius) it uses its far set of lines: a box draws its roof and two corners, the ship its deck and mast, the lighthouse a single stroke. Only the far set's vertices and axis values are worked out.
- **Lines.** Very flat lines (≥ 40:1) are drawn as horizontal runs filled a byte at a time: ~27–37 T a pixel against 45–60. Lines under 24 pixels each way use a plain Bresenham with no slope set-up. Both were checked pixel-for-pixel against the existing drawer (0 bad of 512 test lines).
- **Cost.** The scenery costs speed. Detail 2 averages 6.5 fps over ten views (4.7 at 500 m over the bay, 6.2 on the runway, 5.8 on final) and detail 3 averages 4.5. Each object costs about 3–4k T a vertex and 4k T an edge plus pixels. 16×8 multiplies (axis tables and the cull test) are about 20% of a busy frame. A table-driven multiply is the next speed idea.
- **Default detail is now 2** (scenery on, grid off). The scenery gives the sense of speed that the grid used to.
- **Tests.**
  - The scripted pilot took off at Coral Bay and landed at Coral Bay (grade A, touchdown at 179 m).
  - It pressed N and landed on Turtle Island 09 (grade A, touchdown at 69 m from an aim point of 83 m).
  - `rwtest.py`: 12 position and heading cases for runway choice, range and left/right, all correct.
  - The horizon check: 0 of 40 flights drew ground above the horizon.
  - A missing area file gives the home field and the message.

