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

## Build stages
1. Horizon, panel and flight model as a frame-rate benchmark — **done (this build)**
2. Runway, take-off, landing and the landing grade
3. Locale loader plus the first full locale, Coral Coast
4. Missions, briefing and debrief screens, logbook and save/load
5. Title, attract sequence, music and information screens
6. Riverbend, Red Centre and Ace mode
7. Final polish and the SD disk image

## Stage 1 notes
- Emulator frame rates at 3.375 MHz: detail 1 ~15 fps, detail 2 ~8, detail 3 ~5.5.
- Real hardware (BPM, amber monitor): runs and flies; first build showed "--" FPS because the MC146818 isn't ticking on that machine, and ground lines passing close beside the plane could bend up through the sky (one end's x projection saturated while y didn't). Fixed: vertical-blank field counter for FPS and game time; 3D guard-band clip before projection. Checked with an emulator test that renders random flight states and counts ground pixels above the true horizon (0 of 160).
- Next speed-ups: run-sliced line drawing for shallow lines, analytic edge clipping instead of binary search, faster 16×8 multiply.
- Hardware assumptions (taken from the tested Microbee projects in this repo): port 1Ch b7 premium graphics, b4 attribute RAM, b0–3 PCG bank; port 08h b6 puts colour RAM in the F800 window (low nibble ink, high nibble paper); port 0Bh = 1 during keyboard scans; 6545 status bit 5 (vertical blank) counted as 50 Hz fields for FPS and game time.
