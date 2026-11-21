# Claude Development Brief — Uridium Clone for the VZ300

## Project Overview

Develop a complete, exceptionally polished **Uridium-style arcade shoot-'em-up for the Dick Smith VZ300**, using native graphics hardware and the BennVenn SD Loader with 128 KB RAM expansion.

The objective is to reproduce the extraordinary speed, fluidity, mechanics and arcade feel of Andrew Braybrook's original Commodore 64 Uridium as faithfully as the VZ300 hardware permits.

This is not intended to be a generic horizontally scrolling shooter. It must capture the specific qualities that made Uridium remarkable:

- Extremely fast, smooth bidirectional scrolling.
- Huge dreadnoughts extending far beyond the screen.
- Responsive acceleration and deceleration.
- Beautifully animated 180-degree spacecraft reversals.
- Flying back and forth over detailed battleship surfaces.
- Hostile fighter formations and surface installations.
- Dramatic landing and dreadnought destruction sequences.
- Outstanding responsiveness and addictive arcade gameplay.

**The objective is to create a conversion that makes players forget the VZ300 is displaying only 128 × 64 pixels in four colours.**

Treat this as a complete arcade conversion, not an abbreviated homage or technology demonstration.

## 1. Target Hardware

Target the real VZ300 with:

- Standard Z80 CPU.
- Native VZ300 video hardware.
- MODE(1), 128 × 64 pixels, four colours.
- BennVenn SD Loader with 128 KB RAM expansion.
- Standard VZ keyboard and compatible joystick input.
- Native one-bit audio.
- Standard PAL video timing.

Use expanded RAM intelligently for level layouts, precomputed graphics, code banks, animation data, audio and other resources.

The active graphics mode must remain MODE(1) throughout gameplay.

No enhanced video hardware, external graphics processor or modified machine should be required.

## 2. CRITICAL — Snow-Free 50 FPS Scrolling

**This is one of the two most important engineering challenges in the entire project.**

Target sustained, genuinely snow-free **50 fps PAL scrolling** in both directions, with single-pixel movement wherever practical.

We have already demonstrated in other VZ300 projects that carefully timed Z80 code, including beam-chasing techniques, can achieve remarkably smooth, snow-free 50 Hz graphics on actual hardware.

Do not dismiss this possibility simply because conventional VRAM writing techniques are too slow or produce snow.

**Study and exploit the same principles that made our existing beam-chasing VZ300 engines successful.**

Investigate:

- Beam-synchronised VRAM updates.
- Carefully cycle-counted Z80 routines.
- Drawing behind the raster beam.
- Safe VRAM write windows.
- Incremental horizontal scrolling.
- Pre-shifted graphics data.
- Efficient background restoration.
- Precomputed sprite masks and animation frames.
- Partial redraws and dirty-region updates.
- RAM banking for prepared graphical data.
- Synchronisation of rendering, input and gameplay logic.
- Minimising unnecessary VRAM writes.
- Efficient scheduling of CPU-intensive operations.

The scrolling engine must support rapid acceleration, deceleration and reversal without producing visible discontinuities.

**A consistent 50 fps with slightly simplified graphics is much more desirable than elaborate graphics running inconsistently at 25–30 fps.**

However, don't simply settle for reduced detail without investigating a better rendering architecture.

The goal is to make the game look and feel impossibly smooth for a VZ300.

### Mandatory scrolling acceptance test

Before creating the complete game, build a playable technical demonstration showing:

1. A detailed capital-ship surface extending across several screen widths.
2. Smooth single-pixel horizontal scrolling in both directions.
3. Responsive acceleration and deceleration.
4. Rapid changes in scrolling direction.
5. A moving player spacecraft.
6. Multiple independently moving enemies or test objects.
7. Stable, snow-free graphics.
8. Measured frame timing demonstrating whether 50 fps is genuinely sustained.

Test the engine under a realistic workload, not just with an empty scrolling background.

If the frame rate falls below the target, identify the bottleneck and optimise before proceeding.

Do not claim a snow-free result without appropriate emulator and real-hardware verification. Clearly identify what remains untested.

## 3. CRITICAL — The Animated 180-Degree Flip

**This is the second essential engineering challenge and must be developed alongside the scrolling engine in Phase 1.**

The iconic Uridium reversal manoeuvre is fundamental to the game's identity.

It is not an optional visual effect or something to add after the game engine is finished.

The original spacecraft appears to rotate and roll over as it reverses its horizontal flight direction.

Despite the VZ300's limited resolution, I want a convincing recreation of this manoeuvre.

### Requirements

- A recognisable multi-frame 180-degree roll or flip animation.
- Intermediate frames suggesting the spacecraft rotating in three dimensions.
- Changes in silhouette, apparent width and wing orientation.
- Smooth transitions into and out of the manoeuvre.
- Correct change of horizontal flight direction.
- Immediate and responsive player control.
- Proper interaction with scrolling, movement and collision detection.
- Consistent animation timing without interrupting the 50 Hz rendering schedule.

Investigate whether clever sprite design, precomputed animation frames and carefully controlled changes in sprite width can create a surprisingly convincing three-dimensional illusion.

The low resolution should be treated as a design challenge, not an excuse to replace the manoeuvre with an instantaneous sprite reversal.

### Important gameplay consideration

**The flip must feel like an integral part of flying the spacecraft, not a cutscene.**

The player must not feel that controls have temporarily stopped responding.

Carefully reproduce the acceleration and reversal behaviour that gives Uridium its distinctive feel.

### Mandatory flip acceptance test

The Phase 1 demonstration must show:

1. The spacecraft flying rapidly from left to right.
2. The player initiating a reversal.
3. A convincing animated 180-degree roll.
4. The spacecraft emerging facing left.
5. Immediate continuation of movement in the opposite direction.
6. Repetition of the manoeuvre while scrolling rapidly.
7. No snow, flickering, visible animation corruption or frame-rate collapse.

The test should also demonstrate the manoeuvre while enemy objects are moving independently.

**Do not proceed to full game development with a crude two-frame sprite swap as a placeholder for the finished manoeuvre.**

Develop and validate the actual animation system first.

## 4. Flight Model and Controls

The player craft must feel extremely agile and responsive.

Implement:

- Smooth horizontal acceleration and deceleration.
- Vertical movement across the dreadnought surface.
- Rapid flight in either direction.
- Banking and rolling animations.
- The complete 180-degree reversal manoeuvre.
- Responsive firing.
- Fair collision detection.
- Appropriate player destruction and recovery sequences.

Flight mechanics should remain faithful to Uridium wherever practical.

The controls should encourage fast attack runs, quick reversals and repeated passes over defensive installations.

Support both keyboard and joystick controls.

## 5. Graphics and Art Direction

Use native **128 × 64 four-colour MODE(1)** graphics.

Do not simply reduce the original C64 screenshots until the artwork becomes unrecognisable.

Instead, reinterpret the original graphical concepts specifically for the VZ300's resolution.

### Dreadnought surfaces

The enormous battleships should contain detailed, recognisable mechanical structures:

- Hull plating and structural panel lines.
- Raised command structures.
- Engine housings and ventilation systems.
- Weapon turrets and missile launchers.
- Radar and communications arrays.
- Defensive barriers.
- Power generators.
- Animated machinery.
- Destructible surface targets.

Use dithering, carefully chosen silhouettes, contrasting patterns and selective highlights to create an impression of depth.

Make the capital ships look like enormous mechanical structures beneath the player.

### Colour handling

Investigate both native MODE(1) palettes.

Choose combinations that distinguish the player, enemies, projectiles, obstacles and hull surfaces.

Different dreadnoughts may use different palettes where appropriate.

Any colour changes or raster effects must remain stable on real hardware.

### Software sprites

Develop efficient sprite rendering using techniques such as:

- Masked blitting.
- Pre-shifted animation frames.
- Fast background restoration.
- Compact sprite data.
- Precomputed drawing routines.
- Carefully scheduled display updates.

The player, enemies, projectiles and explosions must coexist without destroying scrolling performance.

## 6. Dreadnought Layouts

Develop substantial, horizontally scrolling enemy dreadnoughts.

Aim to reproduce the scale and progression of the original game, including its full sequence of 15 dreadnoughts if practical.

Each should contain a distinctive arrangement of:

- Surface structures.
- Defensive installations.
- Obstacles.
- Open flight corridors.
- Narrow passages.
- Enemy launch points.
- Landing areas.

Use compressed level data and expanded RAM to create large, varied layouts.

Avoid simple repeating strips of scenery.

Carefully design each level so that its layout remains understandable at the VZ300's resolution.

## 7. Enemies and Combat

Recreate Uridium's characteristic enemy formations and defensive systems.

Include a variety of opponents:

- Fast interceptors.
- Hostile fighter formations.
- Enemies approaching from behind.
- Surface-launched aircraft.
- Defensive turrets.
- Tracking threats.
- Stationary obstacles.

Enemy movement should be distinctive and predictable enough for skilled players to master.

Include satisfying explosions, fair collision detection and visible projectiles.

Implement scoring for destroyed enemies, formations, installations and successful missions.

Avoid excessive enemy density if it compromises visibility or smoothness.

## 8. Landing and Dreadnought Destruction

The landing sequence is an essential part of the Uridium experience.

After the appropriate conditions have been achieved, display a clear **LAND NOW** indication.

The player must locate the landing runway and execute the manoeuvre correctly.

Reproduce the feel of the original landing sequence and associated bonus mechanics.

After landing, provide a satisfying dreadnought destruction sequence.

Consider:

- Animated reactor failures.
- Cascading explosions.
- Hull disintegration.
- Colour flashes.
- Electrical discharge effects.
- Dramatic sound.
- A final escape or strafing run.

These sequences should feel like rewards for completing each mission.

## 9. Sound and Music

Use the VZ300's native one-bit sound hardware creatively.

Investigate established VZ-compatible sound techniques, including efficient multichannel or interleaved one-bit playback where practical.

Include:

- Energetic title music.
- Recognisable weapon sounds.
- Enemy explosions.
- Engine effects.
- Landing alerts.
- Dreadnought destruction sounds.
- Level-completion jingles.
- Game-over and high-score effects.

Sound must not significantly interfere with scrolling or controls.

Complex music may be concentrated in title screens and intermissions if continuous playback proves too expensive.

## 10. Gameplay Polish

Include:

- Keyboard and joystick support.
- Responsive controls.
- Clear scoring and lives display.
- Pause and resume.
- High-score table.
- Attract mode.
- Fair difficulty progression.
- Fast restart.
- Clear landing prompts.
- Consistent enemy spawning.
- Satisfying game completion.

Remain faithful to the original arcade formula.

Do not introduce unnecessary mechanics that distract from Uridium's core gameplay.

## 11. BennVenn SD Loader and Memory Requirements

The game must operate with the **BennVenn VZ300 SD Loader and 128 KB RAM expansion**.

Use expanded memory for:

- Dreadnought layouts.
- Pre-shifted graphics.
- Animation frames.
- Sound and music resources.
- Rendering tables.
- Additional code and level data.

Verify the actual banking mechanism.

Do not assume all expanded RAM is simultaneously accessible.

Investigate the practical loading restrictions of the BennVenn SD environment, including the approximate 31,200-byte limit associated with certain VZ loading workflows.

Use staged loading, banked resources and suitable compression techniques as required.

Consider ZX0, Exomizer or other efficient Z80-compatible decompressors.

Do not introduce disk or SD accesses during active gameplay if these would interrupt the action.

Provide a complete package that launches through the normal BennVenn-compatible workflow on a real VZ300.

## 12. Development Strategy — Mandatory Order

### PHASE 1 — Scrolling and Flip Demonstration

**This phase must establish both the rendering engine and the finished 180-degree flip animation.**

Build a functional demonstration including:

- 128 × 64 MODE(1) graphics.
- A detailed horizontally scrolling dreadnought.
- Bidirectional single-pixel scrolling.
- Beam-synchronised, snow-free rendering.
- A controllable player spacecraft.
- Full acceleration and deceleration.
- A convincing multi-frame 180-degree flip.
- Several independently moving enemies.
- Responsive firing.
- Stable animation during rapid direction changes.
- Measured frame timing under load.

**Do not advance to Phase 2 until the scrolling and flip work together convincingly.**

The scrolling and the flip are not two separate technical demonstrations. They must operate simultaneously in the same playable engine.

If the preferred implementation cannot sustain 50 fps, investigate alternative rendering and scheduling methods and document the measured trade-offs.

### PHASE 2 — Complete Combat Engine

Implement:

- Player control and collision handling.
- Enemy formations.
- Surface defences.
- Projectiles and explosions.
- Scoring and lives.
- Enemy spawning and behaviour.
- Realistic gameplay performance testing.

### PHASE 3 — Dreadnoughts and Progression

Implement the level sequence, dreadnought layouts, landing requirements, bonus sequences, ship destruction and game progression.

### PHASE 4 — Presentation and Audio

Add title graphics, music, sound effects, attract mode, high scores, visual polish and finishing touches.

### PHASE 5 — Hardware Testing and Completion

Produce the final BennVenn-compatible game package.

Verify:

- Reliable SD launch.
- Correct memory banking.
- Stable 50 Hz timing where achieved.
- Snow-free scrolling.
- Repeated animated reversals.
- Heavy combat scenes.
- Audio and display compatibility.
- Level loading.
- Full-game completion.
- Real-hardware compatibility.

## 13. Performance Expectations

Measure actual frame times rather than assuming a 50 Hz interrupt or display synchronisation means the game runs at 50 fps.

Pay particular attention to worst-case scenes.

Test simultaneous scrolling, spacecraft reversal, enemy formations, projectiles, explosions and sound.

Identify CPU bottlenecks and optimise critical routines in Z80 assembly.

Where necessary, simplify secondary visual elements before compromising movement quality.

Do not claim successful real-hardware testing unless the game has genuinely been tested on physical hardware.

Clearly distinguish tested results from emulator-based expectations.

## 14. Deliverables

Provide:

- Complete Z80 assembly source code.
- Graphics and audio source assets.
- Reproducible build scripts.
- A working BennVenn SD-compatible game.
- Required banked or external files.
- Instructions for launching the game.
- Documentation of rendering and scrolling techniques.
- Performance measurements.
- Known limitations and outstanding hardware tests.
- A complete playable game with a proper ending.

Use **"ViBED by BPM"** as the production credit.

For public distribution, use original code and independently created assets rather than copying copyrighted Uridium artwork or music.

## 15. Final Creative Direction

The two features that must define this conversion are:

**1. Exceptionally smooth, snow-free, bidirectional 50 fps scrolling.**

**2. A beautifully animated and immediately responsive 180-degree spacecraft flip.**

These are foundational requirements, not optional finishing touches.

We already know that the VZ300 can deliver remarkably fluid graphics through inventive beam-chasing and cycle-conscious Z80 programming.

Build on that experience.

The finished game should give the impression of flying an agile spacecraft at extraordinary speed over the decks of gigantic enemy warships.

Do not settle for a conventional scrolling shooter merely because that would be easier.

Explore the hardware, measure performance, experiment with rendering techniques and find creative solutions.

**Make it fast. Make it fluid. Make the flip spectacular.**

Above all, produce a complete, enjoyable and technically exceptional game worthy of the VZ300 community.

**ViBED by BPM**