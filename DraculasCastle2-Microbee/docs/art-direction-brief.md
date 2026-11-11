# DRACULA'S CASTLE — MICROBee PREMIUM PLUS
## Complete Monster Artwork, Animation and Visual Presentation Overhaul

### Objective

I want you to undertake a substantial graphical and animation overhaul of the monsters, battle scenes and associated environments in my Dracula's Castle game for the Microbee Premium Plus.

The current artwork was generated from Python vector geometry originally developed for the VZ300 and subsequently scaled to the Microbee's 40×32 character display.

While the existing monsters are recognisable and the compositions are functional, the artwork is too flat, geometric, sparse and visually simplistic. It doesn't come close to exploiting the Microbee's graphical capabilities.

**I want the artwork genuinely redrawn and reimagined for the Microbee, not simply recoloured or rescaled.**

The Microbee Premium Plus has 32 KB of PCG RAM and 1 MB of expanded system RAM. These resources should be exploited intelligently to produce exceptionally detailed artwork and unusually rich character animation for an 8-bit machine.

The goal is to make Dracula's Castle look like a particularly impressive, colourful and characterful commercial 8-bit game, with detailed pixel art, atmospheric environments, expressive monsters and delightful animation.

---

## 1. Overall Art Direction — Groovy Ghoulies!

The central inspiration is the playful, colourful, gothic horror aesthetic of games such as:

- **Grabbed by the Ghoulies** — exaggerated monster personalities and playful horror.
- **Cauldron and Cauldron II** — atmospheric, colourful 8-bit gothic fantasy.
- **Knight Lore** — carefully constructed environments and character silhouettes.
- **Ghosts 'n Goblins and Ghouls 'n Ghosts** — expressive monsters, distinctive enemies and rich environments.
- **Classic ZX Spectrum games** — ingenious colour placement, intricate monochrome detailing and strong use of dithering.
- **Classic 1980s monster cartoons** — humorous, theatrical, mischievous and spooky rather than relentlessly grim.

The game should feel like an enormous, eccentric haunted castle filled with memorable supernatural inhabitants.

Think crooked tombstones, glowing eyes, cobwebs, animated candles, bubbling slime, grinning skulls, crumbling stonework, dusty libraries, flickering torches, sinister stained-glass windows and theatrical villains.

**The tone should be spooky, whimsical, mischievous, colourful and occasionally genuinely menacing.**

Avoid bland vector shapes, generic geometric monsters, excessive empty black space and flat single-colour surfaces.

However, don't make everything excessively busy. Strong silhouettes, readable sprites and carefully placed highlights are more important than indiscriminate detail.

---

## 2. Critical Hardware Constraint — Two Colours per 8×8 PCG

The Microbee has a fundamentally different graphical architecture from a modern framebuffer.

The target presentation uses the Microbee's 40×32 character arrangement, with each PCG character occupying an 8×8 pixel cell.

**Every individual 8×8 PCG cell must contain no more than two actual colours.**

This constraint must be strictly respected.

However, adjacent PCG cells can use different colour combinations, allowing complex, multicoloured characters and scenery to be constructed from many individual cells.

For example, a gargoyle might use:

- White and dark grey for its illuminated face.
- Light grey and black for shaded stonework.
- Purple and black for wing membranes.
- Red and black for glowing eyes.
- Blue and black for moonlit outlines.

Each individual cell must still obey its two-colour restriction.

The visual target is the ingenious colour management seen in the best ZX Spectrum artwork, but adapted to the Microbee's actual PCG architecture and available palette.

Investigate the project's existing PCG rendering, palette, character allocation and colour handling before implementing the overhaul. Do not assume Spectrum attribute behaviour is identical to the Microbee.

### Dithering is essential

Use deliberate pixel patterns to suggest texture, lighting and intermediate shades:

- Checkerboard patterns for transitional shading.
- Sparse stippling for stone, bone and decayed flesh.
- Alternating diagonal patterns for fabric and wing membranes.
- Clustered pixels for organic textures.
- Directional highlights to suggest volume.
- Carefully positioned black pixels for outlines, cracks and crevices.

Dithering should be artistic and material-specific, not merely a generic conversion filter applied to everything.

Avoid noisy patterns that obscure the shapes or make the monsters difficult to recognise.

---

## 3. Mandatory First Stage — Build a PCG Colour Validator

**Before undertaking any substantial artwork redesign, implement an automated hardware-compliance validator for the graphical pipeline.**

This is a prerequisite, not an optional enhancement.

The previous artwork experiments demonstrated how easy it is to produce attractive images that contain three, four or more colours inside individual 8×8 cells.

Such images are not acceptable as final Microbee artwork.

I want a tool that ensures the artwork being produced can genuinely be displayed on the target hardware.

### Validator requirements

The validator must:

1. Examine the final artwork as a grid of 8×8 PCG cells.
2. Count the distinct palette colours used in each cell.
3. Identify any cell containing more than two colours.
4. Report the location of every offending cell using character-grid coordinates.
5. Report the colours found in each offending cell.
6. Produce a visual diagnostic image highlighting invalid cells.
7. Produce a summary showing the total number of cells, valid cells and invalid cells.
8. Return a failure status when invalid artwork is detected, so the build process can reject it.
9. Support validation of every monster, background, animation frame and relevant UI asset.
10. Validate the actual encoded PCG output and associated colour attributes, not just the original source artwork.

### Hardware-accurate previews

I also want the artwork preview system to reproduce the Microbee's actual graphical limitations.

It should display:

- The correct pixel dimensions.
- The correct character-grid arrangement.
- The actual available palette.
- The correct two-colour-per-cell behaviour.
- The same character patterns and colour attributes used by the game.

Where useful, provide an optional overlay showing the 8×8 PCG boundaries.

A particularly useful feature would be a diagnostic mode that displays the number of colours in each cell, with invalid cells highlighted.

### Automatic colour correction

If practical, investigate an optional conversion tool that can suggest or produce hardware-compliant alternatives for invalid cells.

For example, a cell containing black, grey, white and purple might be converted into a carefully dithered two-colour representation.

However, do not blindly quantise the entire image.

Automatic conversion must preserve the artistic intent wherever possible.

Hand-crafted colour selection and dithering should remain the preferred approach for important artwork.

### Build integration

Integrate the validator into the normal asset-generation and build process.

**No artwork should be accepted into a successful production build unless it passes the hardware-compliance checks.**

Also validate PCG allocation, memory limits and any relevant colour-attribute restrictions.

The validator must reflect the Microbee's actual hardware implementation rather than simply assuming that two arbitrary RGB colours can be assigned to every cell.

Once the validator is working, use it throughout the graphical overhaul.

---

## 4. Monster Gallery — Individual Art Direction

Retain the existing monster roster and identities, but substantially enhance each creature.

Each monster should have its own silhouette, colour identity, personality, environment and animation.

### BAT

A mischievous, oversized vampire bat.

Give it large expressive eyes, exaggerated ears, tiny fangs, a rounded furry body and magnificent purple-magenta wings.

Use carefully dithered wing membranes, with black outlines and lighter highlights suggesting stretched skin.

**Background:** A moonlit graveyard with crooked tombstones, wrought-iron fencing, skeletal trees and a bright crescent moon.

**Animation:** Wing flapping, blinking eyes, twitching ears and occasional exaggerated facial expressions.

### SKELETON

A rattling, slightly comical undead warrior.

Replace the existing flat skeletal geometry with a carefully shaded skull, ribcage, pelvis and articulated limbs.

Use white, pale grey and black dithering to suggest the volume and texture of old bones.

Its shield and weapon should have metallic highlights, decorative details and a slightly battered appearance.

**Background:** An ancient crypt with stone arches, wall torches and skull carvings.

**Animation:** Rattling bones, jaw movement, shield movement and an occasional loose bone dropping back into place.

### GHOST

A friendly-looking but unpredictable supernatural apparition.

The ghost should have a flowing, irregular silhouette, exaggerated expressive eyes and a wonderfully animated lower body.

Use white, cyan and pale blue across neighbouring PCGs to suggest supernatural luminosity, while maintaining the strict two-colour-per-cell limitation.

**Background:** A moonlit corridor with tall gothic windows, shadowy alcoves and cobwebs.

**Animation:** Gentle floating, rippling edges, changing expressions and occasional flickering or shimmering.

### GARGOYLE

A substantial improvement over the existing geometric creature.

Make it look like a beautifully carved gothic stone monster coming to life.

It should have a broad muscular chest, crouched limbs, enormous claws, exaggerated horns, sharp fangs and magnificent bat-like wings.

Use layered grey and white dithering to give the stone body convincing depth and texture.

The wings could be purple-grey or charcoal with contrasting highlights.

Its eyes should glow ominously red.

**Background:** A gothic chamber with moonlit windows, carved masonry, decorative pillars and a substantial stone pedestal.

**Animation:** Breathing, blinking red eyes, twitching wings, flexing claws and occasional falling stone dust.

### GRELL

An eccentric floating eyeball monster with a mass of writhing tentacles.

Make the central eye large, glossy and expressive, with a detailed iris and pupil.

Use pink, magenta, red and purple colour combinations to suggest a fleshy, otherworldly creature.

Give its tentacles segmented shading, suction cups or irregular organic details.

**Background:** An alchemist's library with shelves of colourful books, strange bottles, skulls and glowing potions.

**Animation:** Blinking eye, rotating pupil, independently wriggling tentacles and occasional dripping slime.

### ZOMBIE

A shambling, decaying undead character with considerable personality.

Avoid the existing flat fluorescent-green humanoid.

Give it a crooked posture, oversized hands, ragged clothing, mismatched eyes, missing teeth and patches of exposed bone.

Use green and black dithering for decaying skin, purple and black for torn clothing, and pale highlights for exposed bones.

**Background:** A damp dungeon with moss-covered stonework, dripping water and sickly green illumination.

**Animation:** Uneven swaying, jaw movement, reaching arms and occasional twitching.

### SLIME

A gloriously revolting, wobbling blob.

Give it a translucent-looking green body, multiple internal bubbles, large comical eyes and a constantly changing silhouette.

Use carefully chosen green combinations, highlights and stippled patterns to suggest a glossy gelatinous surface.

**Background:** A damp dungeon with glowing green ooze, dripping ceilings and pools of slime.

**Animation:** Squash-and-stretch movement, wobbling, bubbling, blinking and small droplets breaking away.

This monster should be particularly enjoyable to animate using a small number of PCG updates.

### GHOUL KING

A flamboyant, theatrical undead monarch.

Give him a magnificent crown, elaborate purple robes, ornate gold trim, a jewelled staff and a wonderfully expressive skeletal face.

His clothing should have carefully dithered folds and contrasting highlights.

**Background:** A grand throne room with decorative stone columns, flaming braziers, tattered banners and royal insignia.

**Animation:** Glowing eyes, moving jaw, fluttering cloak and an occasional dramatic staff gesture.

He should feel pompous, eccentric and slightly ridiculous, but still dangerous.

### KNIGHT

An imposing haunted suit of armour.

Use white, silver, grey and blue combinations to suggest polished metal, with strong highlights and darker shaded joints.

Give the armour intricate detailing, an expressive visor, a substantial shield and an impressive sword.

**Background:** A mechanical castle chamber with rotating gears, chains, portcullis mechanisms and ancient machinery.

**Animation:** Visor movement, shifting weight, sword movement and occasional metallic glints.

### BAT LORD

A much larger, more sinister relative of the ordinary bat.

Give him dramatic outstretched wings, enormous ears, sharp fangs, glowing eyes and a more powerful silhouette.

Use deep purple, magenta and black with strong highlights and elaborate wing membrane dithering.

**Background:** A moonlit castle rooftop or tower with distant gothic silhouettes.

**Animation:** Slow wing movement, glowing eyes, threatening mouth movements and occasional dramatic wing expansion.

### DRACULA

The theatrical centrepiece of the game.

He should look like a wonderfully exaggerated classic vampire count, with slicked-back hair, pointed ears, pale skin, glowing red eyes, sharp fangs and a magnificent high-collared cloak.

Use black, red, purple and white strategically to create an elaborate appearance within the PCG limitations.

The cloak should have richly dithered folds and a contrasting crimson lining.

**Background:** Dracula's grand chamber, with red stained-glass windows, candlelit stonework, gothic decorations and dramatic shadows.

**Animation:** Opening cloak, revealing fangs, raising hands, blinking eyes and possibly briefly transforming into a swarm of bats.

He should be charismatic, slightly absurd and genuinely imposing.

### BRIDE

An elegant, haunting and slightly mischievous spectral bride.

Give her an expressive pale face, flowing hair, elaborate dress, veil and outstretched ghostly hands.

Use white, pale blue, purple and black combinations to suggest translucent fabric, folds and moonlit highlights.

**Background:** An abandoned chapel or overgrown gothic courtyard with stained glass, roses, vines and a distant moon.

**Animation:** Floating veil, billowing dress, drifting hair and subtle changes in expression.

---

## 5. Environments Must Be Beautiful Too

The current backgrounds are often just thin outlines, simple bricks and large areas of empty black.

I want much more atmospheric scenery, with careful use of the available PCG colour combinations.

Consider:

- Stone blocks with cracks, highlights and individual textures.
- Gothic arches and decorative masonry.
- Stained-glass windows.
- Decorative columns and carved skulls.
- Ornate wooden doors.
- Hanging banners and cobwebs.
- Torches and candles with coloured illumination.
- Bookshelves filled with individually coloured books.
- Moonlit landscapes visible through windows.
- Damp walls, moss, vines and dripping water.
- Perspective floor tiles with dithered surfaces.

Each environment should have its own identity and colour scheme.

However, backgrounds should remain visually subordinate to the monsters. The creatures must always be the focal point.

Use black negative space intelligently rather than filling every cell with unnecessary detail.

---

## 6. Make the Artwork Feel Alive

Static screens should be the exception rather than the rule.

I want the gallery and battle encounters to feel alive through carefully designed animation.

Investigate how the Microbee's programmable character generator can be used to animate repeated or shared patterns without rebuilding entire screens.

Potential effects include:

- Flickering torch flames.
- Animated candlelight.
- Dripping slime.
- Shimmering eyes.
- Waving banners.
- Moving cobwebs.
- Bubbling potions.
- Crawling insects.
- Rippling ghost outlines.
- Subtle breathing and idle animation.
- Occasional lightning illuminating the environment.
- Animated highlights on armour and stone.

Prefer efficient PCG pattern changes, character substitutions and small-region updates where appropriate.

Use the Premium Plus's available PCG RAM and expanded system RAM intelligently for animation frames and artwork storage.

Investigate whether existing CRTC techniques, display page switching or other supported display effects could improve animation smoothness and eliminate flicker.

Do not assume a technique is supported without checking the actual hardware.

Animations should be responsive and smooth without slowing gameplay.

### 6.1 Exploit the Premium Plus's Expanded RAM for Richer Character Animation

The Microbee Premium Plus has **1 MB of expanded system RAM in addition to its 32 KB of PCG RAM**.

This potentially gives us considerably more freedom for character animation than a typical 8-bit machine.

I don't want the animation designs unnecessarily restricted to two or three frames simply because the PCG RAM cannot hold every frame simultaneously.

Investigate using expanded system RAM as a large repository of precomputed character animation frames, with the required PCG patterns transferred into PCG RAM as needed.

This could allow:

**More elaborate idle animations**

Breathing, blinking, swaying, floating, twitching, subtle facial expressions and moving clothing.

**Fluid character movement**

Additional intermediate frames for bats flapping, ghosts billowing, zombies shambling and slimes wobbling.

**Expressive attack animations**

Dracula opening his cloak, the Gargoyle lunging, the Skeleton swinging its weapon and the Grell extending its tentacles.

**Reaction animations**

Characters recoiling, flashing, grimacing, staggering or reacting comically to attacks.

**Special transformations**

Dracula becoming a bat, the Ghost changing shape, the Slime splitting or the Gargoyle awakening from stone.

**Elaborate entrance and defeat sequences**

Monsters emerging from darkness, materialising, crumbling, dissolving or dramatically disappearing.

### 6.2 Animation Storage and Streaming Architecture

Investigate an animation architecture that separates the complete animation library from the currently displayed PCG patterns.

Ideally:

1. Store precomputed animation frames in expanded system RAM, subject to the actual memory banking and addressing capabilities.
2. Maintain a working set of currently required character patterns in PCG RAM.
3. Transfer only changed patterns or character cells when advancing animation frames.
4. Preload the animation frames required for an encounter to minimise disk access during gameplay.
5. Use shared tiles and delta-encoded frames where this reduces memory use or transfer overhead.
6. Consider double-buffered PCG working sets or other verified techniques where these improve smoothness.
7. Coordinate animation updates with display timing to minimise tearing and flicker.
8. Preserve sufficient processor time for gameplay, input handling, music and sound effects.

The expanded RAM provides storage capacity, but does not automatically increase PCG bandwidth or Z80 processing speed.

Investigate the actual transfer costs and choose animation strategies accordingly.

### 6.3 Exploit the Single-Monster Encounter Format

Dracula's Castle generally presents one large monster at a time during combat.

This is a significant advantage.

Rather than keeping every monster's animation data resident simultaneously, consider loading the complete animation set for the current monster into expanded RAM before an encounter.

This could permit much more elaborate animations than would otherwise be practical.

For example, an encounter could preload:

- Multiple idle animation loops.
- Attack anticipation frames.
- Complete attack sequences.
- Hit reactions.
- Special ability animations.
- Defeat sequences.
- Entrance and exit animations.
- Facial expressions and alternate poses.

The game could then switch between these animations without repeated disk access.

Investigate whether compressed animation frames, shared PCG patterns or delta encoding would allow even more animation variety.

### 6.4 Don't Be Unnecessarily Conservative

**I would rather have beautifully animated, expressive monsters than save memory that is otherwise sitting unused.**

If the expanded RAM allows a character to have 12, 16, 24 or more animation frames without compromising responsiveness, take advantage of it.

Not every animation needs that many frames. Allocate additional frames where they genuinely improve the presentation.

For example:

- A gently floating ghost might benefit from a long, smooth looping animation.
- A bat could have a convincing multi-frame wing cycle.
- A slime could use many squash-and-stretch frames.
- Dracula could have a substantial theatrical entrance animation.
- A skeleton might only need a handful of frames for its idle pose, but many more for a dramatic attack or collapse.

The aim is to create the impression of a lavishly animated 8-bit gothic adventure, with characters that feel alive rather than static illustrations occasionally switching poses.

Every animation frame must still pass the strict two-colour-per-8×8-PCG-cell validator.

**Please investigate the Premium Plus memory architecture and exploit its expanded RAM aggressively but intelligently, making full use of the machine's capabilities while maintaining smooth performance on the real Z80 hardware.**

---

## 7. Colour Direction

Use a bold, coordinated 8-bit palette rather than random colour combinations.

Each monster should have a recognisable colour identity.

Suggested visual themes:

| Monster | Dominant colours |
|---|---|
| Bat | Magenta, purple, black |
| Skeleton | White, grey, blue |
| Ghost | White, cyan, blue |
| Gargoyle | Grey, purple, red |
| Grell | Pink, magenta, red |
| Zombie | Green, purple, black |
| Slime | Bright green, dark green |
| Ghoul King | Purple, gold, white |
| Knight | White, grey, blue |
| Bat Lord | Purple, magenta, black |
| Dracula | Black, crimson, purple |
| Bride | White, pale blue, purple |

These are artistic guidelines, not permission to exceed the actual hardware palette or two-colour-per-cell constraint.

Use neighbouring PCGs to achieve multicoloured compositions.

Use black extensively for outlines and contrast.

Bright colours should be concentrated around important character features, magical effects, lighting and environmental focal points.

The overall effect should be vibrant and atmospheric, not garish or visually chaotic.

---

## 8. Preserve the Existing Game

This is primarily a graphical and presentation overhaul.

Preserve the existing gameplay, controls, monster identities, combat mechanics, progression and functional user interface.

The gallery's 40×32 presentation and navigation should remain intact.

Improve the typography, borders, status indicators and other UI graphics where possible, but keep everything readable.

Do not sacrifice gameplay responsiveness for visual embellishments.

The monster artwork should work equally well in the gallery and the actual battle encounters.

Avoid maintaining unnecessarily duplicated graphical assets where common artwork can be shared.

---

## 9. Implementation and Production Optimisation

The Microbee's Z80 processor and PCG architecture should influence the design from the beginning.

The goal is not simply to create beautiful artwork, but to make it run efficiently on real hardware.

### Rendering efficiency

- Avoid unnecessarily redrawing the entire screen.
- Track changed character cells and update only those requiring modification.
- Where supported, animate shared PCG patterns to update repeated scenery efficiently.
- Precompute animation frames rather than generating complex dithering at runtime.
- Precompute colour attributes and PCG references wherever possible.
- Avoid expensive per-pixel processing during gameplay.
- Use lookup tables where they genuinely reduce runtime overhead.
- Minimise unnecessary memory copying and bank switching.
- Keep animation updates predictable and appropriately paced.

### PCG and expanded RAM management

Investigate how the existing project allocates its 32 KB of PCG RAM and 1 MB of expanded system RAM.

Look for opportunities to:

- Share common background tiles.
- Reuse decorative patterns.
- Maintain libraries of animated environmental tiles.
- Load encounter-specific artwork when required.
- Store extensive character animation libraries in expanded RAM.
- Stream animation frames into PCG RAM as needed.
- Preload complete encounter animation sets.
- Compress or delta-encode animation data where beneficial.
- Avoid unnecessary duplication of character definitions.
- Use expanded RAM for additional monster poses, special effects and transitions.

Consider whether the monster gallery and actual battle system can share the same artwork assets and animation routines.

### CRTC and display effects

Investigate supported CRTC techniques that could enhance the presentation.

Potential possibilities include page switching, display-start manipulation, split-screen effects or other techniques demonstrated by existing Microbee projects.

Only implement techniques verified to work on the actual target hardware.

Avoid display effects that introduce instability, flicker, timing problems or incompatibility.

### Performance testing

Measure the cost of rendering and animation on the target Z80.

Check that:

- Input remains responsive.
- Animations maintain consistent timing.
- PCG updates do not introduce visible tearing.
- Memory use remains within the available limits.
- Battle transitions remain reasonably fast.
- Additional visual effects do not interfere with music or sound effects.
- Expanded RAM bank switching does not introduce excessive overhead.
- Animation frame transfers are efficient enough for the intended frame rates.

Prioritise actual hardware performance over emulator-only results.

**Optimise measured bottlenecks rather than sacrificing maintainability through premature optimisation.**

Keep the artwork pipeline understandable and the runtime code reasonably modular so that future monsters and environments can be added without rebuilding the entire rendering system.

---

## 10. Recommended Development Sequence

Please examine the existing project and understand how the original Python vector artwork is generated, converted, stored and displayed.

Then proceed in the following order.

### Stage 1 — Hardware investigation and validation

Before changing the artwork:

1. Confirm the actual Microbee display configuration and colour capabilities.
2. Examine the existing PCG allocation and rendering code.
3. Investigate the Premium Plus's expanded RAM banking and access mechanisms.
4. Implement the mandatory two-colour-per-8×8-cell validator.
5. Implement diagnostic previews showing invalid cells.
6. Integrate validation into the normal asset-generation and build pipeline.
7. Verify that the validator detects deliberately introduced invalid artwork.
8. Establish a reliable hardware-accurate preview system.

**Do not proceed to the major artwork redesign until this stage is working.**

### Stage 2 — Establish the new graphical style

Redesign four representative monsters:

- Gargoyle — stone texture, wings and muscular shading.
- Dracula — clothing, fabric folds, dramatic colour and expressive features.
- Ghost — spectral lighting, flowing outlines and transparency illusions.
- Grell — organic textures, eyes, tentacles and colourful highlights.

These four should demonstrate the full range of techniques needed for the remaining monsters.

Produce hardware-compliant artwork and test it in the actual game.

### Stage 3 — Develop the Expanded-RAM Animation System

Before creating extensive animations for every monster:

1. Establish a reliable system for storing animation frames in expanded RAM.
2. Implement efficient transfer of required patterns into PCG RAM.
3. Investigate shared patterns, compression and delta encoding.
4. Develop a simple animation sequencing system.
5. Test different frame counts and animation update rates.
6. Measure Z80 processing and memory-transfer overhead.
7. Confirm that input, music and sound effects remain responsive.
8. Test the system with a monster that benefits from many animation frames, such as the Ghost or Slime.

Use these tests to determine realistic animation budgets.

The aim is to exploit the available memory without creating an unnecessarily complicated or slow animation system.

### Stage 4 — Complete the Monster Gallery

Apply the established style consistently across the remaining monsters.

Give each monster a distinctive environment, palette and personality.

Create appropriate idle, attack, reaction and defeat animations, taking advantage of expanded RAM where beneficial.

Ensure that every animation frame passes validation.

### Stage 5 — Atmospheric Effects and Presentation Polish

Introduce carefully selected environmental animations, transitions and special effects.

Prioritise techniques that provide substantial visual improvement for relatively little processing overhead.

Use the expanded RAM where appropriate to support richer effects and additional animation sequences.

### Stage 6 — Optimisation and Final Testing

Profile rendering and animation performance.

Improve PCG reuse, memory management, bank switching and update efficiency.

Check every monster and battle scene for colour compliance, visual consistency, responsiveness and stability.

Ensure that the finished game builds successfully and remains playable.

---

## 11. Quality Benchmark

The final artwork should look as though an exceptionally talented 1980s pixel artist spent considerable time making the most of a constrained 8-bit computer.

I want to see:

- Beautifully shaded, dithered monsters.
- Strong character silhouettes and expressive faces.
- Elaborate but readable environments.
- Carefully coordinated colour.
- Atmospheric lighting.
- Memorable, distinctive monster personalities.
- Rich, expressive, multi-frame character animation.
- Smooth idle, attack, reaction and defeat sequences.
- Extensive but efficient use of expanded system RAM.
- Intelligent management of PCG RAM.
- Strict compliance with the actual Microbee hardware.
- Hardware-accurate graphical previews.
- Reliable, automated artwork validation.
- Smooth, responsive gameplay on the target machine.

The game should evoke the reaction:

**"I can't believe that's running on a Microbee!"**

It should be colourful, funny, spooky, atmospheric and technically impressive.

Most importantly, don't be timid with the redesign. The existing vector artwork is a starting point for composition and monster identity, not an artistic standard to preserve.

**Make Dracula's Castle look and feel like a lost, lavishly illustrated, late-1980s gothic arcade adventure that was designed specifically to show off the Microbee Premium Plus.**

And remember: the artwork must not merely look spectacular in a modern PNG preview. It must look spectacular when rendered through the Microbee's real 8×8 PCG system, with its genuine two-colour-per-cell limitations.

The Premium Plus's generous expanded RAM should also allow us to push character animation well beyond what would ordinarily be expected of a Z80-based computer. Take advantage of that opportunity.

*ViBED by BPM*
