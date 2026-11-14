# Ruins: art style guide

Status: APPROVED 2026-11-13 (rev 4, "dark ruins"; approval relayed by the coordinator; rev 4 changes relayed by the coordinator: 4 directions, wall top tile, skeleton helmet; rev 5 on the author's request: darker, calmer floor and lighter wall top, because the brick-like floor made the wall's brick front read as floor). Mass generation still waits for approval of the first sample batch.

## Setting and mood

Dark ruins: cold, damp, desaturated grey-blue stone deep underground, lit only by the hero, torches and magic. The environment is dark and quiet; everything that matters (player, enemies, pickups, hazards, portal) is warm or bright and pops. Readability on a small phone screen comes before detail.

## Technical base

- Viewport 640x360, integer-scaled. Pixel art only, Nearest filtering, no pre-scaled art.
- Grid: 16x16 tiles.
- Perspective: top-down 3/4 (camera from above at about 60 degrees). Floors are seen from above; walls show a top face plus a readable south front face; characters show the top of the head and the front of the body.
- Light: single key light from the top-left. Highlights on top/left edges, shadows on bottom/right.
- Facing: characters have 4 directions (down, up, left, right). Each direction is drawn separately; left is a real left view, never a mirrored right view (asymmetric details like the sword hand, scarf and shield stay on the correct side).
- Skeleton: the helmet is low and rounded (a cap hugging the skull), never tall or pointy.

## Readability rules (dark floor)

1. Value separation: environment uses only the dark stone ramp (palette 1-10). Floors stay in values 5-8; wall front faces in 1-5, wall top faces in 9-10. No actor's main mass (largest areas: body, tunic, shell, armor) may use a color whose value falls in the floor range 5-8 (#2a2935 ... #4c4e5f), including similar-value colors from other ramps (e.g. #1e3f6a, #4a2f22, #263a32, #3b5a45, #4a2a78). Such colors are allowed only as small shadow accents.
2. Accents: every actor and pickup has a warm or bright accent covering at least about a quarter of its pixels (player: blue tunic #3a7ac0/#7ac0f0, orange scarf and skin; skeleton: bright bone; archer: red hood; beetles: teal shells; coin: gold; medkit: red and bone; chest: copper and gold).
3. Rim light: actors get a 1 px rim on the top-left edge, just inside the outline, in the lightest step of their ramp (or #767a8c on dark materials). This separates dark parts (armor, leather) from the dark floor.
4. Outline: actors, pickups and icons have a 1 px outline in #08070b. Because the floor is dark, the outline plus rim light (not the outline alone) is what makes the silhouette read.
5. Shadow: a solid #0f0e14 ellipse under feet, 1-2 px tall, no alpha.
6. Hazards read by shape and accent: spikes have bright steel tips (#9aa2ad / #d8d4c4); pit is near-black (#0f0e14) with a lighter rim on its top edge.
7. Check: view each sprite on a 3x3 patch of the floor tile at 1x. If the silhouette is not obvious within a second, it fails review.

## Base sizes

| Kind | Canvas | Notes |
| --- | --- | --- |
| Tiles (floor, wall, hazards) | 16x16 | must tile seamlessly |
| Player, skeleton, archer | 24x24 | body about 16x20, centered horizontally, feet on row 22; spare space is for the weapon and attack windup |
| Beetle | 16x16 canvas, body about 10x8 | small swarm enemy, kept on 16x16 (scaled with the 1.5x actor size, from 8x6) |
| Golem (later) | 48x48 | body about 32x40 (was 32x32, scaled 1.5x) |
| Ghost (later) | 24x32 | body about 16x26 (was 16x24, scaled 1.5x) |
| Boss: Guardian of the Ruins (later) | 64x64 | body about 52x56 (was 48x48; 72x72 would be too big for a 360 px screen) |

Size change (rev 3): actor sprites were enlarged for readability; collision shapes in the code do not change, the sprite is centered on the existing origin with the feet near the collision bottom. Tiles stay 16x16.
| Pickups (coin, medkit) | 16x16 canvas, object 6-10 px | |
| Chest, gravestone (cover) | 16x16 | |
| Gate with portal | 48x32 (3x2 tiles) | |
| Weapons, UI icons | 16x16 | UI scales them 2x |
| Projectiles (arrow) | 16x16 canvas, arrow about 10x3 | points right |
| Spell effects (later) | 32x32 per frame | |

## Palette (32 colors)

Every pixel must be one of these colors. No other colors, no partial alpha.

| # | Hex | Use |
|---|---|---|
| 1 | #08070b | outline, void |
| 2 | #0f0e14 | pit depth, drop shadows |
| 3 | #17161f | wall darkest, wall mortar |
| 4 | #1f1e29 | wall front face shadow |
| 5 | #2a2935 | wall front face, floor seams |
| 6 | #343442 | floor dark |
| 7 | #3f4050 | floor base |
| 8 | #4c4e5f | floor light, wall top |
| 9 | #5d6072 | stone highlight (wall top edge) |
| 10 | #767a8c | rim light on dark materials, brightest stone |
| 11 | #263a32 | moss dark |
| 12 | #3b5a45 | moss mid |
| 13 | #9aa2ad | steel, bone shadow |
| 14 | #d8d4c4 | bone |
| 15 | #f4f0e0 | bone highlight, brightest |
| 16 | #4a2f22 | leather dark |
| 17 | #7a4a2c | leather, wood |
| 18 | #b07040 | copper, skin shadow |
| 19 | #e0a070 | skin, warm light |
| 20 | #5a1820 | blood dark |
| 21 | #a82a30 | red |
| 22 | #e85a3a | red-orange (player scarf, fire) |
| 23 | #8a4a10 | gold dark |
| 24 | #e09a20 | gold, torch |
| 25 | #ffd860 | gold highlight, sparkles |
| 26 | #1e3f6a | blue dark |
| 27 | #3a7ac0 | blue (rare) |
| 28 | #7ac0f0 | blue light |
| 29 | #4a2a78 | purple dark (portal) |
| 30 | #9a5ae0 | purple light (portal, magic) |
| 31 | #2aa8a0 | teal (beetles, ghost) |
| 32 | #9af0e0 | teal light |

Ramps: stone 1-10 (environment only), moss 11-12, bone/steel 13-15, leather/skin 16-19, red 20-22, gold 23-25, blue 26-28, purple 29-30, teal 31-32.

Rarity accent: common = steel #9aa2ad, rare = blue #3a7ac0, legendary = gold #e09a20.

## Floor and wall look

- Floor: cool, desaturated dark stone, calm and almost uniform: base #343442, a few small marks in #2a2935 (pebble shadows, cracks) and #3f4050 (pebble tops). No slab grid and no edge highlight lines: a floor of bricks or slabs looks like the wall's brick front, and a character in front of a wall then seems to stand on it. Low internal contrast (max 3 adjacent steps), so walls and actors stay brighter. Variants add a crack, a seam fragment with a little moss (#263a32); no bright details.
- Wall tiles, two kinds, chosen per cell:
  - `ruins_wall` (wall cell with floor directly south): top face plus brick front.
  - `ruins_wall_top` (every other wall cell): top face only, full 16x16, main #767a8c, a few #5d6072 marks, bottom row #5d6072 (joint to the next wall cell). Must be clearly lighter than the floor.
- Wall top faces are always much lighter than the floor (#767a8c / #5d6072); front faces are darker than the floor.
- `ruins_wall` layout: top face (upper 5 px) #767a8c, the same as the wall top tile, then a #5d6072 lip row. Front face (lower 10 px) bricks #2a2935 / #1f1e29 with #17161f mortar; bottom row #08070b contact shadow where it meets the floor. The bright top plus dark front face is what makes a wall read as solid.
- Tiles have no black outline except the wall's bottom contact row.

## Shading

3 tones per material, max 4. No anti-aliasing, no dithering under 32 px, no pillow shading, no lone pixels, clean 1-1-1 / 2-2-2 diagonals.

## Animation

| Action | Frames | FPS |
| --- | --- | --- |
| idle | 4 | 6 |
| walk | 4 (6 for bosses) | 10 |
| attack (swing / bow draw and release) | 4-6, windup frames held as telegraph | 12 |
| hit | 2 | 12 |
| death | 4-6 | 10, last frame held |
| coin spin | 4 | 8 |
| portal open loop | 4 | 8 |
| spikes | 3 | 12 |
| spell effects | 4-6 | 12 |

Sheets: one file per animation and direction, named `<name>_<anim>_<dir>.png` (dir = down, up, left, right; e.g. `player_walk_left.png`), each a single horizontal strip, frames left to right, no padding. Feet on the same ground line in every frame. Hit flash and invulnerability blink are done in code.

## File layout

`res://assets/art/<category>/<name>.png` (characters/, enemies/, tiles/, pickups/, weapons/, level/, ui/, fx/). Code keeps using `assets/sprites/*.tres` and `level/ruins_theme.tres`; integration means repointing those resources.

## Prompt template for sprite-generator

```
Subject: <what, pose, key features, accent colors>
Size: <WxH> px canvas, <frames> frames horizontal strip
View: top-down 3/4, facing right, key light from top-left
Palette: only the 32-color Ruins palette (docs/art-style.md), ramps: <ramps>
Style: dark ruins pixel art, 1 px #08070b outline, 1 px top-left rim light, 3-tone shading, must read at 1x on dark grey-blue stone floor
Avoid: anti-aliasing, dithering, gradients, semi-transparent pixels, off-palette colors, background, text, pillow shading, warm/sandy environment colors
```

## Nature theme (secret rooms, the merchant's glade)

Ruins that nature broke into: the same pixel art, 16x16 tiles, 1 px #08070b outline on actors and objects (none on tiles), light from the top-left, 3 tones per material. The palette is warmer and greener than the dark ruins, so these places feel like a reward and a breather.

- Extra colors for this theme only (on top of the 32-color palette): grass #5a8a4a, grass highlight #8ac060, warm lit stone #8a8466 / #6a6656, sunlit stone #9a9470 / #c8c088. Moss #263a32 / #3b5a45, bark #4a2f22 / #7a4a2c and flowers #e0a070 / #ffd860 / #e85a3a come from the main palette.
- Floor: the same old slabs (#3f4050 / #343442, seams #2a2935) with grass and moss growing in the seams and a few small flowers. Values stay in the floor range, so actors still pop.
- Wall front: the same dark bricks with roots crossing them and moss in the mortar; the top strip is grass over warm stone.
- Wall top: grass (#5a8a4a) with a few stones showing through, always much lighter than the floor.
- Light from above: never a random floor variant; a whole sunlit patch (a lighter, warmer floor area, no dynamic light) placed on purpose, e.g. in the middle of the glade.
- Files: `assets/art/tiles/nature_tiles_atlas.png` (slots 0-2 floor, 3 wall front, 4 wall top, 5 cover: a mossy stump, 6 sunlit floor), theme `level/nature_theme.tres`, generator `tools/art/make_nature_tiles.py`, preview `tests/manual/theme_preview.tscn`.
