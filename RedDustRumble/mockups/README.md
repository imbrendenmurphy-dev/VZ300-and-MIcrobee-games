# Main Street arena mock-up (v2, as built in v0.6)

Real 128x64 Mode 1 pictures, using exactly the four MC6847 CSS0 colours: green #07FF00, yellow #FFFF00, blue #3B08FF, red #CC003B.

- `mockup_1x.png` is one pixel per VZ pixel.
- The `_x6` files are enlarged with nearest-neighbour scaling, 6x across and 9x down, which matches the 4:3 screen shape.

They are made by `tools/mockup.py`, which draws the backdrop and stamps on the HUD, the game's real fighter frames and their shadows. Nothing has been painted in afterwards.

| File | Shows |
|---|---|
| `mockup_x6.png` | Squaring off |
| `mockup_left_x6.png` | The camera at the left end of the stage (stable and saloon) |
| `mockup_right_x6.png` | The camera at the right end (hotel and jail) |
| `stage_x6.png` | The whole 192-pixel stage |
| `mockup_bg_x6.png` | The backdrop alone |

## Composition rules

- The fighters are blue or red with yellow detail. Green is the only colour that contrasts with all three, so behind their bodies and arms (rows 28-46) the town fronts are green, with yellow posts, trim and rails. Blue appears there only in small windows and doorways.
- Rows 28-46 (the fighters' heads to their waists) have no dark windows, signs or awnings. Windows and doors there are yellow outlines.
- Hat height (rows 17-26) is a yellow sunset glow, so both Dusty's hat and Flick's jumps stay readable. The sun is red on the glow. The mesa is green with a red sunlit rim, so it works behind either fighter.
- Big masses of blue and red sit above head height (the dusk sky, the saloon's false front) or at the edges (the barrel, the trough).
- Depth comes from layers, back to front: dusk sky, sun and mesa, windmill, the skyline of false fronts (saloon, store, bank, hotel), the boardwalk, the street, and props in the corners.
- Texture is made of horizontal bands, ruled shadow lines, ruts converging on the gap between the buildings, and a handful of 3-pixel gravel clusters. There are no checkerboards and no scattered speckles. The middle of the street, where the feet are, is kept clear.
- Each fighter gets a small green shadow, narrower in the air. It is the only new per-tick drawing.
