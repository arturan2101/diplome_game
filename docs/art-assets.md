# Ruins: art asset checklist

Style: docs/art-style.md. Status: todo / generated / approved / integrated.
Priority: S = first sample batch, C = core, N = nice to have, L = later (if time).
Current placeholders are listed in `assets/sprites/*.tres` (Kenney Tiny Dungeon + placeholder_tiles.png); integration means repointing those resources and `level/ruins_theme.tres`.

Frames notation: idle4/walk4/attack5/hit2/death5 = rows of one sheet.

## Characters and enemies

| P | Asset | File | Size | Frames | Replaces | Status |
|---|---|---|---|---|---|---|
| S | Player idle sample (1 static frame, facing right) | assets/art/characters/player_idle_sample.png | 24x24 | 1 | - | generated |
| C | Player (adventurer) full sheet | assets/art/characters/player.png | 24x24 (body ~16x20) | idle4/walk4/attack5/hit2/death5 | sprites/player.tres | todo (idle + walk done as separate strips, see round 4) |
| C | Player idle/walk, 4 directions | assets/art/characters/player_{idle,walk}_{down,up,left,right}.png | 24x24 per frame, horizontal strip | idle4, walk6 | sprites/player.tres | generated |
| C | Player bow draw | assets/art/characters/player_bow.png | 24x24 | draw4 (last held)/release2 | - | todo |
| C | Player shield block | assets/art/characters/player_block.png | 24x24 | raise2/hold1 | - | todo |
| C | Player dash | assets/art/characters/player_dash.png | 24x24 | 3 | - | todo |
| S | Skeleton idle sample (1 static frame, facing right) | assets/art/enemies/skeleton_idle_sample.png | 24x24 | 1 | - | generated |
| C | Skeleton guard full sheet | assets/art/enemies/skeleton.png | 24x24 (body ~16x20) | idle4/walk4/attack6 (windup 2)/hit2/death5 | sprites/skeleton.tres | todo (idle + walk done as separate strips, see round 4) |
| C | Skeleton idle/walk, 4 directions | assets/art/enemies/skeleton_{idle,walk}_{down,up,left,right}.png | 24x24 per frame, horizontal strip | idle4, walk6 | sprites/skeleton.tres | generated |
| C | Archer | assets/art/enemies/archer.png | 24x24 (body ~16x20) | idle4/walk4/attack5 (windup 2)/hit2/death5 | sprites/archer.tres | todo |
| C | Beetle | assets/art/enemies/beetle.png | 16x16 (body ~10x8) | idle2/walk4/attack4 (windup 1)/hit2/death4 | sprites/beetle.tres | todo |
| N | Stone golem | assets/art/enemies/golem.png | 48x48 (body ~32x40) | idle4/walk4/attack6/hit2/death6 | - | todo |
| N | Ghost | assets/art/enemies/ghost.png | 24x32 (body ~16x26) | idle4/move4/attack5/hit2/death5 | - | todo |
| N | Boss: Guardian of the Ruins | assets/art/enemies/guardian.png | 64x64 (body ~52x56) | idle4/walk6/attack6 x2/summon6/hit2/death6 | - | todo |
| C | Training dummy | assets/art/enemies/training_dummy.png | 24x24 | idle1/hit2 | - | todo |

Actor sizes per docs/art-style.md rev 3: collisions in code are unchanged; sprites are centered on the existing origin.

## Weapons and projectiles

| P | Asset | File | Size | Frames | Status |
|---|---|---|---|---|---|
| C | Sword common / rare / legendary | assets/art/weapons/sword_{common,rare,legendary}.png | 16x16 | 1 | todo |
| C | Bow common / rare / legendary | assets/art/weapons/bow_{common,rare,legendary}.png | 16x16 | 1 | todo |
| C | Sword slash arc | assets/art/fx/slash.png | 32x32 | 3 (+ heavy 3rd hit variant) | todo |
| C | Player arrow | assets/art/weapons/arrow.png (replaces sprites/arrow.tres) | 16x16 | 1 | todo |
| C | Enemy arrow (red fletching) | assets/art/weapons/enemy_arrow.png | 16x16 | 1 | todo |
| L | Spear, axe, crossbow, staff x3 rarities | assets/art/weapons/<name>_<rarity>.png | 16x16 | 1 | todo |

## Pickups and level objects

| P | Asset | File | Size | Frames | Replaces | Status |
|---|---|---|---|---|---|---|
| C | Chest closed | assets/art/pickups/chest.png (frame 0) | 16x16 | 1 | sprites/chest_closed.tres | todo |
| C | Chest open | assets/art/pickups/chest.png (frames 1-3) | 16x16 | 3 (opening) | sprites/chest_open.tres | todo |
| C | Coin | assets/art/pickups/coin.png | 16x16 (coin 6x6) | 4 spin | sprites/coin.tres | todo |
| C | Medkit / health potion | assets/art/pickups/health_pack.png | 16x16 | 1 | sprites/health_potion.tres | todo |
| C | Gravestone (cover) | assets/art/tiles/cover_gravestone.png | 16x16 | 1 | sprites/gravestone.tres, ruins_theme cover_tile | todo |
| C | Gate with portal closed | assets/art/level/gate_closed.png | 48x32 | 1 | sprites/portal_closed.tres | todo |
| C | Gate with portal open | assets/art/level/gate_open.png | 48x32 | 4 loop | sprites/portal_open.tres | todo |
| C | Portal open burst | assets/art/fx/portal_open.png | 32x32 | 5 | - | todo |
| C | Arena door seal (rubble) | assets/art/tiles/door_seal.png | 16x16 | 1 | - | todo |
| N | Spell shrine | assets/art/level/shrine.png | 16x24 | 4 glow | - | todo |
| N | Falling-stone trap (shadow warning + rock + rubble) | assets/art/level/falling_stone.png | 16x16 | warn2/fall3/rubble1 | - | todo |
| N | Pillar (column hall template) | assets/art/level/pillar.png | 16x32 | 1 | - | todo |
| N | Crypt props (sarcophagus, broken statue, bones) | assets/art/level/props.png | 16x16 / 32x16 | 1 each | - | todo |
| L | Skill-tree altar (hub before ruins) | assets/art/level/altar.png | 32x32 | 4 glow | - | todo |
| C | Wall torch (light accent, decorative) | assets/art/level/torch.png | 16x16 | 4 flicker | - | todo |

## Requested by gameplay code

Assets the code already uses with placeholders; integration = repointing the resource in the last column. Added by the gameplay session.

| P | Asset | File | Size | Frames | Code hook | Status |
|---|---|---|---|---|---|---|
| C | Static spikes (always up), ruins style; replaces the "Spikes" row below | assets/art/tiles/ruins_hazards.png (slot 1) | 16x16 | 1 | `level/ruins_theme.tres`: `hazard_texture` + `spikes_tile` | integrated |
| C | Timed spikes, one cell: animations `hidden`, `warn` (0.5 s warning), `rise`, `up` (hurts), `retract` | assets/art/tiles/spikes_timed_frames.tres | 16x16 | any count per animation; the code picks the frame from the phase progress (hidden 1.6 s, warn 0.5 s, rise 0.1 s, up 0.8 s, retract 0.2 s) | `level/spikes_timed.tres`: `frames` | integrated |
| C | Elite shield skeleton (all skeleton animations, shield on the leading side) | assets/art/enemies/skeleton_elite_frames.tres | 24x24 | as the skeleton | `actors/enemies/skeleton_shield.tres`: `sprite_frames` | integrated; the side the shield really blocks is shown by a faint arc drawn in code |
| C | Elite triple-shot archer | assets/art/enemies/archer_elite.png | 16x16 | 1 (still, like the archer) | `actors/enemies/archer_triple.tres`: `sprite` | integrated |
| C | Spawn warning ring (combat-room waves) | actors/effects/spawn_warning.tscn | 32x32 | 8 | `actors/enemies/spawn_marker.gd`: `look_scene` | integrated; the marker sets the ring's `z_index` to 0 after it is ready (at -1 the ring was drawn under the floor tiles) and puts itself first among the section's nodes, so the ring is above the floor and below the actors |
| N | Animation of the triple-shot archer (idle, walk, shoot), like the other enemies | assets/art/enemies/archer_elite_frames.tres | 24x24 | as the skeleton | `actors/enemies/archer_triple.tres`: `sprite_frames` | todo |
| C | Cracked wall (front and top) | assets/art/tiles/ruins_tiles_atlas.png slots (6, 0), (7, 0) | 16x16 | 1 each | `level/ruins_theme.tres`: `cracked_wall_tile`, `cracked_wall_top_tile` (the level draws `LevelGrid.cracked` cells with them) | integrated |
| C | Wall collapse | actors/effects/wall_collapse.tscn | 16x24 | 6 | `level/breakable_wall.gd`: `collapse_scene` | integrated |
| C | Nature theme (secret rooms, the glade) with the sunlit floor | level/nature_theme.tres | 16x16 | - | `level/level.gd`: `DEFAULT_REGION_THEMES` (`&"nature"`); `sunlit_floor_tile` (slot 6) under the light from above | integrated |
| C | Merchant and wandering merchant (idle), goods carpet | assets/art/characters/merchant_frames.tres, merchant_wander_frames.tres, assets/art/props/merchant_carpet.png | 24x24, 32x16 | idle 4 | `actors/npc/merchant.gd`: `frames`, `wandering_frames`, `carpet` | integrated |
| N | Light shaft from above (soft warm beam, bottom centre on the node) | assets/art/fx/light_shaft.png | about 32x48 | 1 | `level/light_shaft.gd`: `texture` | todo (drawn in code) |
| N | Shop screen: panel frame, item slots, icons | assets/art/ui/trade_panel.png, trade_slot.png, shop_icons.png | 24x24, 20x20, 16x16 | 1 | `ui/shop_screen.tscn` | art ready; wired in stage 25 (the glade) |

Check spike sprites with `tests/manual/spikes_preview.tscn` (saves the five phases side by side).

## Tilesets (per biome)

Biome 1 "Sandstone ruins" (core). Later biomes reuse the same layout: flooded ruins, jungle ruins (L).

| P | Asset | File | Size | Frames | Status |
|---|---|---|---|---|---|
| S | Floor base | assets/art/tiles/ruins_floor.png (col 0) | 16x16 | 1 | generated |
| C | Floor variants (cracks, moss, debris) x3 | assets/art/tiles/ruins_floor.png (cols 1-3) | 16x16 | 1 each | todo |
| S | Wall (top + south front face) | assets/art/tiles/ruins_wall.png (col 0) | 16x16 | 1 | generated (hand-drawn, round 4: lighter top) |
| S | Wall top (no floor to the south: side walls, wall interiors) | assets/art/tiles/ruins_wall_top.png | 16x16 | 1 | generated (hand-drawn) |
| S | Floor variants 2 and 3 | assets/art/tiles/ruins_floor_2.png, ruins_floor_3.png | 16x16 | 1 each | generated (hand-drawn) |
| C | Wall variants x2 (brick, crumbled) | assets/art/tiles/ruins_wall.png (cols 1-2) | 16x16 | 1 each | todo |
| N | Wall autotile set (edges, corners) | assets/art/tiles/ruins_wall_set.png | 16x16 cells, 47-tile or 16-tile blob | - | todo |
| C | Pit top edge (rim) | assets/art/tiles/pit.png (col 0) | 16x16 | 1 | todo |
| C | Pit inner | assets/art/tiles/pit.png (col 1) | 16x16 | 1 | todo |
| N | Pit side/corner edges | assets/art/tiles/pit.png (cols 2-7) | 16x16 | 1 each | todo |
| C | Spikes | assets/art/tiles/spikes.png | 16x16 | 3 (retracted, half, up) | todo |
| L | Flooded ruins floor/wall/pit set | assets/art/tiles/flooded_*.png | 16x16 | as above | todo |
| L | Jungle ruins floor/wall/pit set | assets/art/tiles/jungle_*.png | 16x16 | as above | todo |

## UI icons

| P | Asset | File | Size | Frames | Replaces | Status |
|---|---|---|---|---|---|---|
| C | Sword icon | assets/art/ui/icon_sword.png | 16x16 | 1 | sprites/sword_icon.tres | todo |
| C | Bow icon | assets/art/ui/icon_bow.png | 16x16 | 1 | sprites/bow_icon.tres | todo |
| C | Dash icon | assets/art/ui/icon_dash.png | 16x16 | 1 | sprites/dash_icon.tres | todo |
| C | Shield/block icon | assets/art/ui/icon_block.png | 16x16 | 1 | sprites/shield_icon.tres | todo |
| C | Coin icon (HUD) | assets/art/ui/icon_coin.png | 16x16 | 1 | - | todo |
| C | Heart / HP icon | assets/art/ui/icon_hp.png | 16x16 | 1 | - | todo |
| C | Weapon swap icon | assets/art/ui/icon_swap.png | 16x16 | 1 | - | todo |
| C | Pause icon | assets/art/ui/icon_pause.png | 16x16 | 1 | - | todo |
| C | Take / interact icon | assets/art/ui/icon_take.png | 16x16 | 1 | - | todo |
| C | Joystick base + knob | assets/art/ui/joystick.png | 48x48 + 16x16 | 1 | - | todo |
| C | HP bar frame + fill | assets/art/ui/hp_bar.png | 64x8 | 1 | - | todo |
| C | Rarity frames (common/rare/legendary) | assets/art/ui/rarity_frame.png | 18x18 x3 | 1 | - | todo |
| C | Menu/death-screen panel and button (9-slice) | assets/art/ui/panel.png, button.png | 16x16 9-slice each | 1 (button: normal/pressed) | - | todo |
| C | Depth/section icon | assets/art/ui/icon_depth.png | 16x16 | 1 | - | todo |
| N | Parry, teleport skill icons | assets/art/ui/icon_{parry,teleport}.png | 16x16 | 1 | - | todo |

## Spell effects (later)

| P | Asset | File | Size | Frames | Status |
|---|---|---|---|---|---|
| L | Fireball (projectile + explosion) | assets/art/fx/fireball.png | 16x16 / 32x32 | 4 / 6 | todo |
| L | Ice wall | assets/art/fx/ice_wall.png | 16x32 | 4 | todo |
| L | Whirlwind | assets/art/fx/whirlwind.png | 32x32 | 6 | todo |
| L | Teleport | assets/art/fx/teleport.png | 32x32 | 5 | todo |
| L | Stone shield | assets/art/fx/stone_shield.png | 32x32 | 4 | todo |
| L | Fire tornado (combo) | assets/art/fx/fire_tornado.png | 32x32 | 6 | todo |
| L | Ice fortress (combo) | assets/art/fx/ice_fortress.png | 32x32 | 6 | todo |
| L | Spell icons x7 | assets/art/ui/spell_<name>.png | 16x16 | 1 | todo |

Generic FX (C): hit spark 16x16 x3, dust puff (dash/land) 16x16 x4, death poof 16x16 x4, pit fall 16x16 x3.

---

## Sample batch 1 prompts (waiting for approval of the style guide)

Style: "dark ruins" (docs/art-style.md rev 2). Common suffix for all four: "Palette: only the 32-color Ruins palette in docs/art-style.md. Avoid: anti-aliasing, dithering, gradients, semi-transparent pixels, off-palette colors, background, text, pillow shading, warm/sandy environment colors."

**1. Player, idle sample** (`assets/art/characters/player_idle_sample.png`, 24x24 canvas, ONE static idle frame, facing right; animations come later)
Young ruin explorer standing at rest, top-down 3/4 view facing right, key light from top-left. Body about 16x20 px, centered horizontally, feet on row 22, transparent margin around it. Tunic main tone #3a7ac0 with #7ac0f0 highlight/rim on top-left; #1e3f6a only as a small shadow accent (under the arm and belt line), never as the main mass. Red-orange scarf and hood trim (#a82a30/#e85a3a), warm skin (#b07040/#e0a070), small leather belt and boots (#7a4a2c, #4a2f22 only in shadows), short steel sword held low in the right hand (#9aa2ad with #f4f0e0 edge glint). 1 px #08070b outline, 1 px top-left rim light, 3-tone shading, #0f0e14 shadow ellipse under feet. No main-mass color in the floor value range (#2a2935-#4c4e5f and equivalents). Must be the clearest, warmest thing on a dark grey-blue stone floor at 1x.

**2. Skeleton guard, idle sample** (`assets/art/enemies/skeleton_idle_sample.png`, 24x24 canvas, ONE static idle frame, facing right; animations come later)
Skeleton warrior standing guard, top-down 3/4 view facing right, key light from top-left. Body about 16x20 px, hunched and bony, centered, feet on row 22. Bright bone body (#f4f0e0/#d8d4c4, shadows #9aa2ad) so it pops on the dark floor, black eye sockets (#08070b) with red glints (#e85a3a), rusted copper helmet and small round shield (#b07040 main, #8a4a10 shadow), notched steel short sword (#9aa2ad) held ready, leaving space in the canvas for a later windup. 1 px #08070b outline, #f4f0e0 rim light on top-left, #0f0e14 shadow ellipse. No main-mass color in the floor value range.

**3. Floor tile** (`assets/art/tiles/ruins_floor.png`, 16x16, 1 frame)
Seamless top-down floor of old dark stone slabs in an underground ruin, cool and desaturated grey-blue. Two or three irregular slabs per tile: faces #3f4050 and #343442, seams #2a2935, a few #4c4e5f highlight pixels on top-left slab edges, one or two hairline cracks in #2a2935. Low contrast (only colors 5-8 of the palette), no bright pixels, no outline, nothing that makes repetition obvious. Must tile seamlessly in all four directions.

**4. Wall tile** (`assets/art/tiles/ruins_wall.png`, 16x16, 1 frame)
Top-down 3/4 dark ruin wall block, darker than the floor. Top 6 px: stone top face #4c4e5f with a 1 px #5d6072 highlight on its top and left edge so the wall line reads from above. Bottom 10 px: south front face of dark stone bricks #2a2935 and #1f1e29 with #17161f mortar, two brick rows, a tiny moss patch (#263a32) on one brick. Bottom row #08070b contact shadow where the wall meets the floor. Clear contrast between bright top edge and dark front face. Seamless horizontally.

## Sample batch 1 results (2026-11-13, PixelLab create_image_pixen, 1 static frame each, separate files)

Cleanup in Aseprite (batch Lua): alpha thresholded (no semi-transparent pixels found), every pixel snapped to the nearest color of the 32-color palette; tiles were snapped to the stone ramp only (floor: colors 5-8, wall: 1-9 + 11). Canvas sizes confirmed: 24x24, 24x24, 16x16, 16x16. lint_sprite: no lone or detached pixels on the actors.

- player_idle_sample.png: prompt 1 above, condensed (same colors and instructions), options: direction east, view high top-down, black outline, transparent. 1 generation. 19 colors. Small (body about 10x19), reads more as side view, outline is broken in places, tunic is mostly dark, not #3a7ac0. Needs review.
- skeleton_idle_sample.png: prompt 2 above, condensed, same options. 1 generation. 15 colors. Bone body is greyish (#9aa2ad / #767a8c, i.e. stone tones) rather than bright bone; red helmet crest and shield read well. Needs review.
- ruins_floor.png: retry 1 used (the first result was a framed ornament with orange and moss). Prompt used: "seamless repeating texture of dark grey-blue stone floor slabs seen from directly above, irregular flagstones with thin dark seams, cold desaturated dungeon floor, low contrast, edge to edge, no border, no frame, no objects" (low detail, lineless). 2 generations. Only 3 colors after snapping (#2a2935, #343442, #4c4e5f), noisy rather than clear slabs; edge mismatch left/right 3/16, top/bottom 4/16 pixels (close to seamless, but not perfect).
- ruins_wall.png: FAILED, all three attempts (1 + 2 retries) produced a centered object instead of a wall tile. The saved file is retry 1 (prompt: "seamless dungeon wall tile, top-down 3/4 view: upper third is a flat lighter grey stone top surface with a bright top edge, lower two thirds is a dark grey-blue brick front face with two rows of bricks and dark mortar, black shadow line along the bottom, fills the whole tile edge to edge, no background, no border"), a rock blob, palette-clean and seamless only because its edges are flat. 3 generations. Not usable; suggestion: draw it by hand in Aseprite from the spec (it is simple geometry) or try another tool (create_tiles_pro / create_topdown_tileset) after approval.

## Sample batch 1, round 2 (2026-11-13, replaces the files above)

- ruins_floor.png: drawn by hand in Aseprite (no AI). 4 slabs on a 16x16 grid with #2a2935 seams on row 0, row 8, col 0 and staggered verticals; faces #3f4050 / #343442, #4c4e5f top-left edge highlights, two #2a2935 hairline cracks. Colors 5-8 only. Seamless in both directions: the shared seam lines meet at the wrap (checked on a 3x3 patch). Fairly regular brick-like layout; variants can break it up.
- ruins_wall.png: drawn by hand in Aseprite (no AI). Rows 0-5 top face (#5d6072 top edge, #4c4e5f face), row 6 #17161f mortar, two brick rows (#2a2935 top / #1f1e29 bottom rows, #17161f mortar, staggered joints), moss #263a32 at x13-14 y12-13, row 15 #08070b. Left-edge highlight left out on purpose: it showed as a vertical stripe every 16 px in a horizontal run. Seamless horizontally (checked on a 3x3 patch).
- player_idle_sample.png: PixelLab create_character (standard mode, 4 directions, size 19, chibi, high top-down, black outline, low detail), east rotation only. Prompt: "young ruin explorer adventurer, stocky, bright blue tunic, red-orange scarf and hood, warm skin, brown leather belt and boots, short steel sword held low in right hand, clear bold silhouette". First try at size 24 was 25 px tall (did not fit with feet on row 22) and was discarded. Cleanup: snapped to palette, edge darks to #08070b, tunic #1e3f6a to #3a7ac0 (old #3a7ac0 to #7ac0f0), interior darks to #08070b / #1e3f6a, #0f0e14 shadow row added at y23. Body 12x20, feet on row 22. No separate rim light.
- skeleton_idle_sample.png: same tool and options. Prompt: "skeleton warrior guard, stocky, bright white bone skull ribs and limbs, black eye sockets with red glints, rusted copper helmet, round copper shield, steel short sword held forward, clear bold silhouette". First try at size 24 was thin and almost all black and was discarded. Cleanup: snapped to palette, interior black to bone #d8d4c4, #d8d4c4 to #f4f0e0, #0f0e14/#767a8c to #9aa2ad, #7a4a2c to #8a4a10, hand-placed eye socket (#08070b) with #e85a3a glint and two #9aa2ad rib pixels, shadow row added. Body 14x21, feet on row 22. Reads as a bright figure but only weakly as a skeleton (helmet and shield dominate); needs review or hand touch-up.

## Sample batch 1, round 3: characters (2026-11-13, replaces the round 2 character files)

Tool: PixelLab create_character_pro_flash, 8 directions, high top-down, palette = the 32 Ruins colors ("Ruins 32"), 6 generations per character. Only the east idle rotation is used. Cleanup in Aseprite: cropped to the bounding box, placed on 24x24 centered with feet on row 22, snapped to palette (output was already on palette, no semi-transparent pixels), dark edge pixels to #08070b, #0f0e14 shadow row at y23.

PixelLab character IDs (keep for animations):
- Player (USED): `4459ec17-e479-409e-bcda-e4bf0966c233` "ruins_player", 24x24 request (rotations come on a 32x32 canvas). Style image: the round 2 player_idle_sample.png. Prompt: "young ruin explorer adventurer, small figure about 16 px wide and 20 px tall with transparent margin, feet near the bottom, bright blue tunic, red-orange scarf and hood, warm skin, brown leather belt and boots, short steel sword held low in right hand, 1 px near-black outline, light from top-left, readable bold silhouette". Extra cleanup: tunic #1e3f6a to #3a7ac0, #3a7ac0 to #7ac0f0, interior #2a2935/#343442 to #1e3f6a. Body 13x18.
- Skeleton (USED): `221efe47-c84d-490b-8f45-adfa37a6dc9c` "ruins_skeleton_v2", 32x32 request. Style image: south rotation of the player above (outline/shading/proportions only, colors not copied). Prompt: "undead skeleton guard, figure exactly about 16 px wide and 20 px tall centered with wide transparent margin, feet near the bottom, unmistakably a skeleton: large bright white bone skull with two black eye sockets and tiny red glints, white ribcage with black gaps between the ribs, thin white bony arms and legs, mostly bright bone white overall, tiny copper helmet cap and small round copper shield as minor accents, notched steel short sword, 1 px near-black outline, light from top-left". Extra cleanup: helmet #e85a3a to #b07040 and #263a32 to #8a4a10, red eye glint at (10,10). Body 13x18. The shield is not visible from the east.
- Not used: `eff0e659-26f1-4c84-8bc1-9de1d0ff5a02` (skeleton attempt 1, east view almost all black and gold, no readable skull), `9fd80e72-39cc-4ea8-9e59-5b80c311e11a` (player attempt 2, 32x32, east view 9 px wide with a gold face).

Readability (3x3 floor + wall row, scratchpad check_on_floor_4x.png): skeleton reads clearly as a skeleton (bright skull and bones, highest contrast on the floor). Player reads by the red hood; the blue tunic is small, the sword is visible. Both bodies are 13x18, a bit under the 16x20 target.

## Round 4 (2026-11-13): animations, helmet fix, wall top, floor variants

Layout decision: separate files per animation and direction, each a horizontal strip of 24x24 frames, no padding. Directions: down = south, up = north, right = east, left = west (real west views from PixelLab, not mirrored). Frame rates per the style guide (idle 6 fps, walk 10 fps).

Animations: PixelLab animate_character, template mode, directions south/north/east/west, 1 generation per direction: 16 generations in total.
- Player 4459ec17-e479-409e-bcda-e4bf0966c233: idle = template "breathing-idle" (group e373e1da-4766-489c-9bc6-4132dd0b39fb, 4 frames), walk = template "walking" (group d0e74232-4aec-40f7-a23a-06de6260bde5, 6 frames).
- Skeleton 221efe47-c84d-490b-8f45-adfa37a6dc9c: idle "breathing-idle" (group 2994368e-c4e1-42b1-a43c-db29bd69f8d6, 4 frames), walk "walking" (group 94f2aa35-b7fb-4efa-8e2e-eddde7391c74, 6 frames).
- Cleanup in Aseprite (script per strip): one shared bounding box per strip (no jitter), centered on 24x24, lowest pixel on row 22, snapped to the palette, dark edge pixels to #08070b, #0f0e14 shadow row at y23 with the same width in every frame. Player: tunic #1e3f6a to #3a7ac0. Skeleton: red/moss/gold helmet colors to copper.
- Skeleton helmet fix (every frame): everything above the first skull row was removed and replaced by a low 2-row cap: a #08070b outline row 1 px narrower on each side (rounded), then one copper band (#e0a070 highlight on the left, #b07040, #8a4a10 on the right, one #4a2f22 dent pixel), with the skull visible below.
- The *_idle_sample.png files were replaced by frame 0 of *_idle_right.png.
- Known issues: the walk template drops the player's sword in most frames; body sizes are 9-14 x 17-20 px (under the 16x20 target); skeleton idle-down still shows some copper on the face area.

Tiles (hand-drawn in Aseprite, no AI):
- ruins_wall_top.png: flat #5d6072 with a few #767a8c / #4c4e5f specks, bottom row #2a2935 (as asked; this makes stacked wall-top tiles show a faint line every 16 px vertically, otherwise seamless in all directions).
- ruins_wall.png: top 6 px changed to row 0 #767a8c, rows 1-4 #5d6072 with specks, row 5 #4c4e5f; front face unchanged.
- ruins_floor_2.png, ruins_floor_3.png: same tones and the same border seams (row 0, column 0) as ruins_floor.png, different slab layouts and cracks, so any mix tiles seamlessly.
- Check: a 10x7 tile room (wall-top border, front wall row, mixed floor variants) with both characters, scratchpad room_check_4x.png.

## Spikes (art, 2026-11-13)

- Static spikes (always raised): slot 1 of `assets/art/tiles/ruins_hazards.png` (the theme's `spikes_tile`).
- Retractable spikes: `assets/art/tiles/spikes_timed_frames.tres` (16x16), animations `hidden` (plate with slots, loop), `warn` (the plate trembles, steel glints in the slots, loop, 12 fps), `rise` (2 frames, once), `up` (raised, loop), `retract` (3 frames, once). Strips: `spikes_timed_<state>.png`. To use them, point `frames` of `level/spikes_timed.tres` at this file (the mechanics session owns that resource).
- Generator: `tools/art/make_spike_tiles.py`.

## Elite enemies and the wave warning (art, 2026-11-13)

- Shield skeleton: `assets/art/enemies/skeleton_elite_frames.tres` (all skeleton animations: idle, walk, attack, hurt, death; dark red helmet and armour instead of copper, glowing yellow eyes, a big dark red shield on the leading side). To use: `sprite_frames` of the shield skeleton's EnemyData (or the AnimatedSprite2D of its scene).
- Triple-shot archer: `assets/art/enemies/archer_elite.png` (16x16 still, like the ordinary archer: dark red cloth, three arrow heads above). To use: `sprite` of `actors/enemies/archer_triple.tres`.
- Wave / elite spawn warning: `actors/effects/spawn_warning.tscn` (`SpawnWarning`, a flat ring on the floor that grows and turns brighter for `duration` seconds, 0.8 by default, then frees itself; strip `assets/art/fx/spawn_warning.png`, 8 frames 32x32). Add it at the spawn cell and spawn the enemy when it is done.
- Generator: `tools/art/make_elite_frames.py`. Wiring into the mechanics session's files is left to that session.

## Secret wall (art, 2026-11-14)

- Cracked wall tiles in `assets/art/tiles/ruins_tiles_atlas.png`: slot (6, 0) brick front with a thin crack, slot (7, 0) wall top with a crack. They look like ordinary walls from afar; up close the dark zig-zag with a lit lip is visible. To use: the level draws a secret wall cell with these instead of `wall_tiles` / `wall_top_tiles` (needs a theme field and a line in the level code, mechanics session).
- Collapse: `actors/effects/wall_collapse.tscn` (`WallCollapse`): put it at the centre of the wall cell when the wall opens; it plays `assets/art/fx/wall_collapse.png` (6 frames 16x24: crack spreads, blocks fall, rubble), throws dust and stone chips, leaves the rubble about 3 s and frees itself.
- Generator: `tools/art/make_secret_wall.py`.

## Nature theme (art, 2026-11-14)

- `level/nature_theme.tres` (TileTheme): give it to a Level (its `theme`) for a secret room or the glade; hazards use the ruins hazard atlas. Sunlit floor tile: slot (6, 0) of `assets/art/tiles/nature_tiles_atlas.png`, for a placed light patch, not a random variant. Style: docs/art-style.md, "Nature theme".

## Merchant and glade (art, 2026-11-14)

- Merchant (24x24): `assets/art/characters/merchant_frames.tres`, animation `idle_down` (4 frames, 4 fps: breathing, the lantern flickers). An old man in a deep purple hood with a white beard and a glowing lantern. Wandering merchant (secret rooms): `merchant_wander_frames.tres`, the same man in a green hood with a travel pack. Use an AnimatedSprite2D with offset (0, -4) like the other 24x24 actors.
- Goods carpet 32x16: `assets/art/props/merchant_carpet.png`, drawn in front of the merchant.
- Shop icons 16x16, strip `assets/art/ui/shop_icons.png` in this order: health potion, sword, bow, scroll, shield, key, coin pouch, gem (region x = index * 16).
- Trade window: `assets/art/ui/trade_panel.png` (24x24, NinePatchRect / StyleBoxTexture with 8 px margins) and `trade_slot.png` (20x20 item frame with a gold edge).
- Glade: ground = slot (7, 0) of `nature_tiles_atlas.png` (open grass), a sunlit patch of slot (6, 0) in the middle with old slabs (slots 0-2) around it; props `assets/art/props/broken_column.png` (16x24) and `big_tree.png` (32x26) around the edges, no collision in the sprites.
- Generator: `tools/art/make_merchant.py`.

## Elements by level (art, 2026-11-14)

Each element has 3 levels: bigger, brighter, more particles; level 3 adds a new detail. Files in `assets/art/fx/`, generator `tools/art/make_element_frames.py`.
- Fire (the fireball): `fire_l1..3` in `element_frames.tres` (4 frames, 12 fps; level 1-2 16x16, level 3 24x24 with a long flame tail), flies to the right (rotate to the direction). Level 3 also leaves `fire_trail` (16x16, 4 frames, burning ground).
- Ice (a block of the ice wall): `ice_l1.png`, `ice_l2.png`, `ice_l3.png` (16x16; taller and shinier each level, level 3 with a frost rim on the floor).
- Wind (the whirlwind ring): `wind_l1..3` in `element_frames.tres` (48x48, 4 frames, 12 fps, flat on the ground; more rings each level, level 3 carries stones and leaves).
- HUD: `element_icons.png` (16x16: fire, ice, wind) and `level_pips.png` (16x4 each, level 1, 2, 3: gold marks under the icon).
- Wiring by level is for the session that owns the spells (pick the animation or texture by the spell's level).
