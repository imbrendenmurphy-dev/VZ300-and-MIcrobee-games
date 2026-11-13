# Microbee Premium Plus — Bomberman-Inspired Arcade Game
## Complete game development brief for Claude

*BPM's brief for this project, kept as written.*

### Overall vision

Create an exceptionally polished, colourful, fast, entertaining and highly playable original arcade game inspired by the best elements of the Bomberman series.

Preserve the wonderfully addictive core mechanics of Bomberman — navigating intricate arenas, strategically placing bombs, destroying obstacles, triggering chain reactions, collecting power-ups and outsmarting enemies — while building upon the formula with new ideas, inventive stage mechanics, interesting enemies, memorable bosses and substantial gameplay variety.

This should be a major original Microbee Premium Plus title, not a straightforward Bomberman conversion or imitation.

It should have the production values, personality and attention to detail of a professionally developed late-1980s or early-1990s arcade or console game.

Above all, it must be **fun, responsive, fair and rewarding to play**, rather than punishingly difficult.

### 1. Creative freedom — title, characters and identity

You have considerable creative freedom to develop the game's identity.

Please choose your own:

- Original, memorable game title.
- Main character or characters.
- Visual style and artistic direction.
- Overall setting, themes and atmosphere.
- Enemy designs and personalities.
- World concepts and stage environments.
- Humour, narrative and presentation.
- Additional gameplay ideas that distinguish the game from Bomberman.

Do not feel obliged to reproduce Bomberman's traditional character designs, visual identity or storyline.

The intention is to capture what makes the Bomberman formula so enjoyable while creating a distinctive game that feels purpose-built for the Microbee.

Develop a coherent creative direction and choose an appropriate title as the game's personality emerges.

Do not let the examples later in this brief restrict your imagination. They are suggestions, not mandatory design decisions.

### 2. Target hardware

Develop specifically for the Microbee Premium Plus, investigating and accurately using its hardware capabilities.

The intended target includes:

- Native Z80 CPU, approximately 3.375 MHz.
- 32 KB of programmable character generator (PCG) RAM.
- Approximately 1 MB expanded system RAM, subject to the actual banking arrangement.
- Colour and monochrome display capabilities.
- Programmable 6545-compatible CRTC.
- Double-sided, 80-track floppy disk storage.
- Native speaker audio.
- Keyboard and suitable joystick support.

The game should run using the native Z80 hardware, without relying on the ColdFire processor for gameplay acceleration.

Investigate actual hardware characteristics and existing documentation rather than relying on assumptions.

Make intelligent, ambitious use of the machine's capabilities.

The expanded RAM and disk storage should allow a substantial game with generous quantities of artwork, animations, levels, music and other assets.

### 3. Display mode and screen composition

I strongly favour the Microbee's lower-resolution display modes because their character cells have more pleasing, square-looking proportions.

Please investigate the available display modes, particularly the native 40-column arrangements, and select whichever offers the best balance of attractive proportions, useful playfield size, colour, animation and performance.

Do not automatically select the highest-resolution display mode.

You may also investigate alternative CRTC configurations where they offer genuine advantages and operate correctly on the target hardware.

The aim is to produce attractive, well-proportioned arcade graphics without the overly tall, narrow character cells associated with some Microbee display arrangements.

Consider constructing each logical gameplay tile from multiple PCG cells.

For example, a 2×2 arrangement would permit greater graphical detail and potentially different colour combinations within each gameplay tile.

However, you are free to devise a better arrangement after investigating the available screen geometry.

The playfield should be large enough to support interesting tactical gameplay while leaving space for a polished status display.

Ensure the proportions of the characters, enemies, bombs, obstacles and scenery are visually pleasing.

### 4. Critical requirement — bitmap-style PCG animation

**This is one of the most important aspects of the entire project.**

The Premium Plus should not be treated as a simple fixed-character or static tile machine.

Its programmable character generator can be manipulated dynamically to produce bitmap-style graphics and animation.

The substantial PCG RAM capacity makes much more elaborate character animation, visual effects and scenery possible than would be practical on a machine with fixed character graphics.

Please actively exploit this capability.

Consider techniques such as:

- Dynamically rewriting PCG pixel patterns.
- Allocating dedicated PCGs for animated objects.
- Pre-rendering multiple animation frames in PCG RAM.
- Software compositing characters over background graphics.
- Pixel-level movement within character cells.
- Pre-shifted animation frames.
- Dirty-cell rendering.
- PCG caching and intelligent reuse.
- Animation frame banking or staged transfers from expanded RAM.
- Combining multiple PCGs into larger animated graphical objects.
- Changing colour attributes selectively for lighting and animation effects.

Particularly important is the possibility of **smooth, pixel-level character movement**, rather than merely jumping between character cells.

Although gameplay and collision detection may use a logical grid, the visible characters should move smoothly and convincingly between grid positions.

The protagonist should have lively, detailed walking and running animation, directional movement and expressive reactions.

Enemies should have their own distinctive movement and animation styles.

Bombs, explosions, destructible scenery and environmental objects should also benefit from dynamically manipulated PCGs.

Of course, CPU performance is finite. Investigate and prototype the practical techniques, measure their costs and choose efficient combinations.

Static scenery can remain inexpensive character-based graphics, while more computationally intensive bitmap-style animation is concentrated on active objects.

The goal is to make the game feel much more graphically sophisticated than a conventional character-cell game without sacrificing responsiveness.

### 5. Art direction and colour

Aim for rich, characterful, attractive arcade graphics.

The visual style should be colourful and distinctive, with expressive characters, detailed scenery, memorable enemies and satisfying animation.

You may draw inspiration from the presentation quality of polished 8-bit and 16-bit console games, but develop an original artistic identity.

The Microbee's two-colours-per-PCG-cell constraint must be respected.

However, individual cells within a larger sprite or scenery tile may use different colour combinations, permitting more complex, multi-coloured artwork.

Exploit this creatively.

Consider strong silhouettes, careful colour selection, highlights, shadows, pixel dithering and interesting combinations of PCGs.

Avoid drab, repetitive or excessively simplistic graphics.

The game should look as though considerable care has been lavished upon every element.

Develop a coherent visual language for hazards, walkable areas, destructible obstacles, items and enemies.

The player must always be able to understand what is happening, even during spectacular chain reactions.

Provide a monochrome presentation option where practical, but **colour should be the primary artistic target**.

### 6. Character animation and personality

Characters should have considerable personality.

The main character should feature detailed animation appropriate to its design, potentially including:

- Animated idle poses.
- Blinking, fidgeting or other subtle movement.
- Directional walking and running.
- Bomb-placement animation.
- Reactions to nearby explosions.
- Collecting power-ups.
- Damage and defeat animations.
- Victory celebrations.
- Contextual interactions with the environment.

Use bitmap-style PCG manipulation where it improves the quality of the animation.

Consider squash-and-stretch effects, expressive faces, secondary motion and exaggerated arcade-style movement.

Enemies should be equally characterful.

Their behaviour and animations should help communicate their abilities and personalities.

A large roster of varied, attractively animated enemies would be preferable to a small collection of barely distinguishable creatures.

### 7. Core Bomberman-inspired gameplay

Retain the central appeal of Bomberman.

The player navigates a grid-based arena containing permanent obstacles, destructible blocks, enemies, environmental hazards and collectible items.

Bombs can be placed strategically to destroy obstacles and defeat enemies.

Explosions propagate in recognisable patterns, usually along the four cardinal directions, with their reach determined by the current bomb power.

Obstacles block or modify explosions according to clear rules.

Bombs can trigger other bombs, producing satisfying chain reactions.

Destructible scenery can reveal items, hidden areas, secrets or new routes.

The fundamental gameplay loop should be immediately understandable and enjoyable.

**Controls must be exceptionally responsive.**

Consider modern quality-of-life refinements:

- Forgiving movement around corners.
- Sensible directional input buffering.
- Predictable bomb placement.
- Fair collision detection.
- Brief opportunities to escape a newly placed bomb.
- Clear warnings before dangerous effects occur.
- Quick restarts.
- Reasonable checkpoints and continues.
- Difficulty options.
- Optional tutorials introduced naturally through gameplay.

Avoid cheap deaths or excessively demanding timing.

The game should reward intelligent positioning and experimentation rather than merely memorising enemy patterns.

### 8. Build upon the formula

I do not want the game limited to simply clearing one repetitive arena after another.

Develop additional mechanics that expand the basic Bomberman formula.

Possible ideas include environmental switches, movable obstacles, conveyor belts, teleporters, doors, destructible machinery, ice surfaces, moving hazards and interconnected stage objectives.

Bombs might be used to operate machinery, open routes, activate switches, defeat unusual enemies or solve environmental puzzles.

Some levels could introduce alternate explosive types or unusual terrain.

Other stages might require rescuing characters, collecting objects, reaching an exit or completing special challenges.

These are suggestions rather than a prescribed feature list.

Feel free to invent more interesting alternatives.

The additions should enrich the core gameplay rather than overcomplicate it.

The result should remain a lively, immediately accessible arcade game.

### 9. Power-ups and abilities

Provide a generous selection of meaningful power-ups.

Traditional possibilities include:

- Additional bombs.
- Increased explosion range.
- Increased movement speed.
- Remote detonation.
- Bomb kicking.
- Bomb throwing.
- Temporary shields.
- Additional lives or health.
- Temporary invulnerability.

Consider original abilities as well.

Examples might include bouncing bombs, secondary explosions, bombs that freeze enemies, explosives that activate machinery, or tools that reposition bombs.

You are free to devise a more imaginative system.

Power-ups should be visually distinctive, accompanied by satisfying audio cues and introduced in a balanced fashion.

Avoid making the player so overpowered that the tactical gameplay disappears.

Consider which abilities are temporary, which can be accumulated and which may persist through the campaign.

### 10. Substantial single-player campaign

Create a significant single-player adventure featuring multiple visually distinct worlds and numerous levels.

I would like at least five major worlds or environments, preferably more if practical.

Each world should feature:

- Distinctive graphical design.
- Its own scenery and tile vocabulary.
- Different environmental mechanics.
- A recognisable enemy roster.
- New challenges and gameplay ideas.
- Appropriate music and sound.
- A memorable boss encounter.

Aim for a substantial campaign, perhaps 40–50 levels or more, depending on level variety and available storage.

There is no need to fit the entire game into a single small memory allocation.

Use the expanded RAM and floppy disk system intelligently.

Worlds should feel genuinely different rather than merely reusing the same arenas with different colours.

Develop an enjoyable progression from simple introductory challenges to more elaborate, inventive stages.

Avoid the punishing difficulty often associated with old arcade games.

Progression should feel rewarding and achievable.

### 11. Enemies and artificial intelligence

Populate the game with a diverse collection of enemies.

Different creatures should have recognisable behaviour, movement patterns, animation and abilities.

Some may wander, patrol or chase the player.

Others might flee from bombs, navigate hazards, create obstacles, move blocks, use explosives or interact with the environment.

More advanced enemies may anticipate explosions or attempt to trap the player.

Use efficient AI appropriate to a Z80-based machine.

The aim is convincing and interesting behaviour, not computationally expensive algorithms.

Enemies should behave consistently enough that skilled players can learn to outsmart them.

Give different enemies different personalities through animation, sound and reactions.

### 12. Boss encounters

Every major world should culminate in an imaginative boss battle.

Bosses should be visually impressive, substantially larger than ordinary characters where appropriate, and richly animated using multiple PCGs.

The Premium Plus's dynamic PCG capabilities should be particularly valuable here.

A boss might have independently animated components, moving limbs, expressive facial features, flashing damage indicators or elaborate destruction sequences.

Develop attack patterns that make creative use of bombs and arena mechanics.

Boss battles should have readable phases, recognisable vulnerabilities, visual warnings and interesting tactical challenges.

Avoid unfairly fast attacks or unpredictable instant deaths.

Completing a boss battle should be a memorable event, with satisfying animation, sound and celebration.

### 13. Explosions and special effects

Explosions are central to the game's visual identity and should be spectacular.

Make them lively, substantial and satisfying.

Consider:

- Animated expanding flame patterns.
- Distinctive explosion centres and tips.
- Pixel-level flame animation.
- Bright colour flashes.
- Rolling, flickering or pulsing flames.
- Debris and particle effects.
- Smoke, sparks or embers.
- Animated block destruction.
- Multiple overlapping explosions.
- Energetic chain reactions.
- Appropriate screen shake or CRTC effects.
- Satisfying synchronised sound.

Explore whether colour attributes and selective PCG updates can produce particularly inexpensive visual effects.

Destructible scenery should not simply disappear if an attractive destruction animation can be achieved affordably.

Objects might crack, crumble, shatter, collapse or dissolve.

Use the expanded RAM to provide more animation frames and visual variety than a conventional small-memory Microbee game.

However, **clear gameplay information must always take priority over visual spectacle**.

The player should never be confused about which cells are dangerous.

### 14. Animated environments

The arenas should feel alive.

Consider inexpensive environmental animation such as flashing lights, moving machinery, rippling water, flickering flames, rotating fans, pulsing electrical panels or animated vegetation.

Where possible, use PCG character substitution or shared animation frames to animate multiple instances at very low CPU cost.

Use dynamic bitmap-style PCG manipulation selectively for more elaborate effects.

Background animation should never interfere with the clarity of moving characters, hazards or explosions.

Investigate whether CRTC effects, page switching or other hardware techniques can improve presentation.

Only adopt such techniques after verifying their practicality on the actual Premium Plus.

### 15. Music, jingles and sound effects

Audio should receive as much attention as the graphics.

Develop a capable and efficient sound engine for the Microbee's native speaker.

Investigate multi-channel-style music using techniques such as rapid time slicing, arpeggios, percussion and carefully timed waveform output.

The aim is lively, characterful arcade audio.

Include:

- A memorable title theme.
- Distinctive music for different worlds.
- Boss battle music.
- Victory fanfares.
- Power-up jingles.
- Bonus and secret-area music.
- Warning sounds.
- Animated, punchy explosion effects.
- Individual enemy and character effects.
- Menu and interface sounds.

Bombs should have distinctive placement and detonation sounds.

Large chain reactions should sound particularly satisfying.

Investigate techniques used in other successful 1-bit Z80 music engines, but do not assume that code from another machine can be used unchanged.

The sound engine must coexist efficiently with game logic, PCG manipulation and animation.

Stable gameplay takes priority over excessive audio complexity.

Provide options to disable music or sound effects separately where feasible.

### 16. Additional game modes

Beyond the single-player campaign, consider several additional modes.

**Two-player Battle Mode**

A competitive local multiplayer mode in which two players attempt to outmanoeuvre and defeat one another.

Include dedicated battle arenas, optional hazards, power-ups and adjustable match rules.

Investigate support for keyboard and joystick combinations.

**Cooperative Mode**

Two players work together through selected campaign levels or specially designed cooperative challenges.

Consider mechanics that reward teamwork without making the controls complicated.

**Survival Mode**

Fight progressively more challenging waves of enemies and attempt to achieve a high score.

**Challenge or Puzzle Mode**

Short self-contained levels that reward clever bomb placement, timing and use of special abilities.

**Computer-controlled opponents**

Investigate AI opponents for battle mode, with the number of simultaneous competitors determined by actual performance.

Prioritise the core campaign and excellent basic gameplay before expanding into secondary modes.

### 17. Title screen, attract mode and presentation

The finished game should have the lavish presentation we've come to appreciate in our other original Microbee and VZ300 projects.

Once you have developed the game's creative identity, choose a memorable original title.

Design a beautiful title screen featuring large custom graphical lettering, attractive illustrations, animation and music.

Use programmable characters to construct artwork that looks far more sophisticated than ordinary text-mode graphics.

Include an arcade-style attract sequence demonstrating actual gameplay.

The complete presentation should include:

- Animated title screen.
- Memorable introductory music.
- Attract mode.
- Polished menus.
- Clear instructions.
- Difficulty and control options.
- World introductions.
- Attractive loading transitions.
- High-score tables.
- Bonus and victory sequences.
- A satisfying ending.
- Credits.

Between worlds, consider illustrated interludes that combine relatively static artwork with selective animation.

Include the credit:

**ViBED by BPM**

Avoid unfinished-looking debug screens, crude text menus or abrupt transitions in the completed game.

### 18. Expanded RAM and asset management

Make substantial use of the Premium Plus's expanded system RAM.

Investigate the actual memory banking arrangement and how best to access the available memory from native Z80 code.

Possible uses include:

- Multiple sets of world artwork.
- Large libraries of animation frames.
- Compressed PCG graphics.
- Character and enemy sprites.
- Music and sound data.
- Level maps.
- Boss artwork.
- Precalculated movement and animation data.
- Render buffers and working storage.
- Saved game data and persistent progress.

The 32 KB PCG RAM should be managed as a valuable graphical resource.

Plan which graphics remain resident, which can be reused, and which should be dynamically updated.

Consider a PCG allocation or caching system that allows frequently used graphics and animated objects to coexist efficiently.

Take particular care when dynamically modifying PCGs shared by multiple screen locations.

Moving sprites must not accidentally alter background scenery or other instances of the same character.

Investigate methods for compositing graphical objects and restoring backgrounds correctly.

### 19. Floppy disk support and saving

The game should be distributed as a suitable Microbee Premium Plus floppy disk image compatible with the available double-sided, 80-track disk system.

Ideally, the disk should boot to a normal DOS prompt, from which the game can be launched using a straightforward command.

Use disk storage for substantial asset libraries, additional world data, music and other content.

Load assets efficiently, preferably between levels or worlds rather than during time-critical gameplay.

Where useful, retain multiple assets in expanded RAM to reduce loading delays.

Implement disk-based saving for:

- Campaign progress.
- Unlocked worlds and levels.
- Relevant abilities and upgrades.
- High scores.
- Settings and preferences.

Saving and restoring should be reliable and straightforward.

Do not assume a particular disk format, DOS interface or memory layout without checking the target environment.

### 20. Performance and rendering architecture

The Microbee's Z80 CPU is not particularly fast, so this game needs a carefully designed rendering architecture.

However, the PCG system offers opportunities to make attractive graphics relatively inexpensive.

Investigate an approach that combines static character-based scenery with dynamic bitmap-style PCG animation for active objects.

Potential techniques include:

- Pre-rendered animation frames.
- Pixel-shifted graphics.
- Dedicated animated PCGs.
- Dirty-cell and dirty-region rendering.
- Efficient Z80 assembly routines.
- Selective PCG updates.
- Optimised background restoration.
- Animation scheduling.
- Precomputed lookup tables.
- CRTC-assisted effects where feasible.

Experiment with multiple logical render buffers if helpful, but avoid copying unnecessarily large portions of display memory.

Consider whether the PCG RAM permits sprite animation or background effects through inexpensive character selection rather than constant graphical reconstruction.

Pay particular attention to worst-case situations:

- Several moving enemies.
- Two players.
- Multiple simultaneous bombs.
- Large overlapping explosions.
- Long chain reactions.
- Animated scenery.
- Active music and sound effects.

The game must remain responsive during these situations.

Aim for smooth visual motion and a stable update cadence. Select a sustainable frame rate from measurements rather than promising an unrealistic target.

Separate gameplay logic timing from rendering where necessary.

### 21. Quality of life, difficulty and fairness

The game must be enjoyable rather than gruelling.

Introduce mechanics gradually and reward experimentation.

Offer appropriate difficulty settings, checkpoints and continues.

Ensure enemies and hazards behave predictably enough to feel fair.

Provide:

- Responsive controls.
- Forgiving movement.
- Quick restarting.
- Sensible difficulty progression.
- Clear visual warnings.
- Attractive, readable status information.
- Convenient game saving.
- Optional sound settings.
- High-score tracking.
- Accessible introductory levels.

Include secrets and bonus challenges for experienced players, but don't require exceptional reflexes simply to complete the campaign.

The player should feel encouraged to progress.

### 22. Development approach

Please approach this as a serious, substantial game development project rather than a small proof of concept.

However, establish the technical foundations before attempting to implement every feature.

**First, investigate the hardware.**

Confirm the most appropriate lower-resolution display mode, actual PCG RAM organisation, colour capabilities, memory banking and disk interfaces.

**Second, prove the graphical techniques.**

Create a representative arena demonstrating attractive multi-PCG tiles, detailed character artwork and bitmap-style PCG animation.

Pay particular attention to whether pixel-smooth movement and dynamic PCG updates can be achieved efficiently.

**Third, establish the core gameplay.**

Implement responsive movement, bomb placement, animated explosions, destructible scenery, power-ups and several distinct enemies.

**Fourth, measure performance.**

Benchmark the worst-case combination of characters, animation, explosions, effects and audio.

Optimise the rendering engine before expanding the content.

**Fifth, develop the full game.**

Build the campaign, additional environments, bosses, multiplayer modes, music, presentation and disk-saving facilities.

**Finally, polish everything.**

Refine controls, balance difficulty, eliminate rendering artefacts, improve animation, add personality and test the game extensively.

Do not consider the project complete merely because its basic mechanics work.

### 23. Expectations and creative initiative

I want you to contribute substantial creative and technical initiative to this project.

Please don't interpret the brief as a rigid checklist that prevents better ideas from emerging.

If you identify an especially interesting gameplay mechanic, clever graphical technique, unusual setting, distinctive character design or imaginative boss concept, pursue it.

Likewise, if an ambitious feature proves too expensive for the Z80, find a visually convincing and efficient alternative.

The target is a complete, polished, original game that demonstrates the Microbee Premium Plus at its best.

The game should use the machine's unusual strengths rather than trying to imitate another platform through brute force.

The combination of expanded system RAM, 32 KB PCG RAM, dynamically manipulated character graphics, flexible CRTC facilities and floppy disk storage should allow something genuinely distinctive.

**I am particularly interested in seeing the PCG graphics manipulated as bitmap graphics for detailed, expressive animation. Don't unnecessarily constrain the visual presentation to static tiles or character-cell movement.**

At the same time, respect the practical limitations of the hardware and ensure the finished game is responsive, reliable and enjoyable on a real machine.

### Final objective

Produce a game that makes someone encountering the Microbee Premium Plus for the first time genuinely surprised by what the machine can do.

It should have beautiful graphics, distinctive characters, smooth animation, delightful sound, inventive gameplay, numerous varied levels, memorable bosses, polished presentation and substantial replay value.

Most importantly, it should be the kind of game someone returns to simply because it is so enjoyable to play.

**Give it your own title, your own personality and your own creative vision. Make it a signature arcade game for the Microbee Premium Plus.**
