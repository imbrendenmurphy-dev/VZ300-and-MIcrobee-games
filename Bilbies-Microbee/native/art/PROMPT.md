# Homestead art source

Generated with the built-in imagegen tool on 2026-11-02. The original
transparent PNG is retained unchanged as homestead-source.png. This is a
high-resolution source asset, not an emulator screenshot. assets.py derives
the native RGBI and PCG data at build time; no API call is needed to rebuild.

Final prompt:

Use case: stylized-concept. Asset type: a production reference sprite for a
native Microbee Premium Plus pixel-art puzzle game, Bilbies!, an Australian
game. Create ONE isolated Australian rural station homestead, in a side-on
game view with a slight suggestion of depth. Recognisably Australian
federation/outback homestead: long low weatherboard house, broad shaded
wraparound verandah, thin timber verandah posts and cross-braced railing,
corrugated galvanised iron hip roof with subtle corrugations, a brick
chimney, deep shaded sash windows, worn steps, a round corrugated rainwater
tank at one side. Charming, carefully hand-pixelled, believable proportions
and small architectural detail; organic weathering, no chunky toy blocks.
No text, no UI, no people, no animals, no terrain, no horizon; genuine
transparent background. Compose the entire house and tank with generous
transparent margin, wide sprite about 3:1. The intended final art is around
240 by 96 native pixels: crisp deliberate single-pixel texture and clean
silhouettes, not a scaled four-colour computer screenshot. Use ONLY a
restrained subset of the Microbee's RGBI colours: black #000000, dark grey
#606060, light grey #c0c0c0, white #ffffff, dark red #c00000, ochre #c0c000,
dark green #00c000, blue #0000c0 and cyan #00c0c0. Roof mostly greys,
weathered pale walls, warm red/ochre accents, window interiors dark. Sparse
ordered dithering for shaded cream timber and iron. No smooth gradients,
no antialiasing, no photorealism, no isometric building, no voxel blocks.
This is a new native-resolution art reference, not an edit of any supplied
screenshot. Hardware conversion to two colours per 8x16 cell will be
performed by the game asset compiler later.

The native compiler currently uses 312x48 pixels for the house to compensate
for tall 80-column video pixels. Two-colour-per-cell encoding is lossy, and
the source does not represent the final machine's attainable colour detail.
