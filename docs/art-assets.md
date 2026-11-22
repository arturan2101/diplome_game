# Ruins: art asset checklist

Style: docs/art-style.md. Status: todo / generated / approved / integrated.
Priority: S = first sample batch, C = core, N = nice to have, L = later (if time).
Current placeholders are listed in `assets/sprites/*.tres` (Kenney Tiny Dungeon + placeholder_tiles.png); integration means repointing those resources and `level/ruins_theme.tres`.

Frames notation: idle4/walk4/attack5/hit2/death5 = rows of one sheet.

## Ready to wire in (generated, not in the game yet; checked 2026-11-18)

Details, sizes and hooks are in the tables below.
- Player: bow draw, shield block, dash strips (`characters/player_{bow,block,dash}_<dir>.png`), not in `player_frames.tres` yet.
- Enemies: elite archer animation (`enemies/archer_elite_frames.tres`), ghost (`ghost_frames.tres`), training dummy (`training_dummy.png`). The stone golem is in the game since stage 29.
- Pickups and level: chest, coin, health potion (`pickups/`), gate with portal 48x32 and its opening burst, torch, column, sarcophagus, bones, statue, shrine and used shrine (`level/`), arena door rubble and floor decals (`tiles/`).
- Combat: sword slash and heavy slash (`fx/slash*.png`), player and enemy arrows, swords and bows in three rarities (`weapons/`).
- Effects and light: hit spark, dust puff, death poof, pit fall, light textures (`fx/`).
- UI: HUD icons, joystick, HP bar, rarity frames, panel and button (`ui/`).
- Still Kenney or placeholder in `assets/sprites/*.tres`: arrow, bow / sword / dash / shield icons, chest, coin, gravestone, health potion, portal, shrine, and the still archer / beetle / guardian pictures.

## Characters and enemies

| P | Asset | File | Size | Frames | Replaces | Status |
|---|---|---|---|---|---|---|
| S | Player idle sample (1 static frame, facing right) | assets/art/characters/player_idle_sample.png | 24x24 | 1 | - | generated |
| C | Player (adventurer) full sheet | assets/art/characters/player.png | 24x24 (body ~16x20) | idle4/walk4/attack5/hit2/death5 | sprites/player.tres | integrated: strips player_<anim>_<dir>.png (idle, walk, attack, hurt, death) in player_frames.tres, used by player.tscn; bow / block / dash strips generated 2026-11-17, not in player_frames.tres yet |
| C | Player idle/walk, 4 directions | assets/art/characters/player_{idle,walk}_{down,up,left,right}.png | 24x24 per frame, horizontal strip | idle4, walk6 | sprites/player.tres | generated |
| C | Player bow draw | assets/art/characters/player_bow_<dir>.png | 24x24 | 6: draw 4 (frame 3 = held), release 2 | - | generated 2026-11-17 (PixelLab, tools/art/import_player_actions.py) |
| C | Player shield block | assets/art/characters/player_block_<dir>.png | 24x24 | 4: raise 2, hold 2 | - | generated 2026-11-17 (PixelLab, tools/art/import_player_actions.py) |
| C | Player dash | assets/art/characters/player_dash_<dir>.png | 24x24 | 4 | - | generated 2026-11-17 (PixelLab, tools/art/import_player_actions.py) |
| S | Skeleton idle sample (1 static frame, facing right) | assets/art/enemies/skeleton_idle_sample.png | 24x24 | 1 | - | generated |
| C | Skeleton guard full sheet | assets/art/enemies/skeleton.png | 24x24 (body ~16x20) | idle4/walk4/attack6 (windup 2)/hit2/death5 | sprites/skeleton.tres | integrated: strips skeleton_<anim>_<dir>.png in skeleton_frames.tres, used by skeleton.tres |
| C | Skeleton idle/walk, 4 directions | assets/art/enemies/skeleton_{idle,walk}_{down,up,left,right}.png | 24x24 per frame, horizontal strip | idle4, walk6 | sprites/skeleton.tres | generated |
| C | Archer | assets/art/enemies/archer.png | 24x24 (body ~16x20) | idle4/walk4/attack5 (windup 2)/hit2/death5 | sprites/archer.tres | integrated: strips archer_<anim>_<dir>.png in archer_frames.tres, used by archer.tres (2026-11-14) |
| C | Beetle | assets/art/enemies/beetle.png | 16x16 (body ~10x8) | idle2/walk4/attack4 (windup 1)/hit2/death4 | sprites/beetle.tres | integrated: strips beetle_<anim>_<dir>.png in beetle_frames.tres, used by beetle.tres (2026-11-14) |
| N | Stone golem | assets/art/enemies/golem_<anim>_<dir>.png, golem_frames.tres | 48x48 (body ~34x40) | idle4/walk4, attack/hurt/death from the importer | - | integrated in stage 29: `actors/enemies/golem.tres` (`sprite_frames`); wanted next: a slam shockwave on the floor (fx/golem_shockwave.png, 64x64, 6 frames) |
| N | Ghost | assets/art/enemies/ghost_<anim>_<dir>.png, ghost_frames.tres | 32x32 frames (body ~18x31; square like the other strips) | idle4/move4 (as walk), attack/hurt from the importer, own death 4 | - | generated 2026-11-17 (see "Golem and ghost" below) |
| N | Boss: Guardian of the Ruins | assets/art/enemies/guardian.png | 64x64 (body ~52x56) | idle4/walk6/attack6 x2/summon6/hit2/death6 | - | integrated: strips guardian_<anim>_<dir>.png in guardian_frames.tres, used by guardian.tres (2026-11-14) |
| C | Training dummy | assets/art/enemies/training_dummy.png | 24x24 | idle1/hit2 (one strip of 3) | - | generated 2026-11-17 (tools/art/make_world_props.py) |

Actor sizes per docs/art-style.md rev 3: collisions in code are unchanged; sprites are centered on the existing origin.

## Weapons and projectiles

| P | Asset | File | Size | Frames | Status |
|---|---|---|---|---|---|
| C | Sword common / rare / legendary | assets/art/weapons/sword_{common,rare,legendary}.png | 16x16 | 1 | generated 2026-11-17 (tools/art/make_ui_icons.py) |
| C | Bow common / rare / legendary | assets/art/weapons/bow_{common,rare,legendary}.png | 16x16 | 1 | generated 2026-11-17 (tools/art/make_ui_icons.py) |
| C | Sword slash arc | assets/art/fx/slash.png (48x48, reach 24, 120 deg), slash_heavy.png (64x64, reach 28, 160 deg, gold) | 48x48 / 64x64, centred on the wielder, pointing right | 3 each (wind-up, full arc, fading; flip vertically for the swing back) | generated 2026-11-17 (replaces the polygon of melee_weapon.gd _draw) |
| C | Player arrow | assets/art/weapons/arrow.png (replaces sprites/arrow.tres) | 16x16, pointing right, tip at (14, 8) | 1 | generated 2026-11-17 (replaces the line of arrow.gd _draw) |
| C | Enemy arrow (red fletching) | assets/art/weapons/enemy_arrow.png | 16x16, pointing right, tip at (14, 8) | 1 | generated 2026-11-17 |
| L | Spear, axe, crossbow, staff x3 rarities | assets/art/weapons/<name>_<rarity>.png | 16x16 | 1 | spear, daggers, crossbow generated 2026-11-18 (plan group 3); axe and staff todo |

## Pickups and level objects

| P | Asset | File | Size | Frames | Replaces | Status |
|---|---|---|---|---|---|---|
| C | Chest closed | assets/art/pickups/chest.png (frame 0) | 16x16 | 1 | sprites/chest_closed.tres | generated 2026-11-17 |
| C | Chest open | assets/art/pickups/chest.png (frames 1-3) | 16x16 | 3 (opening) | sprites/chest_open.tres | generated 2026-11-17 |
| C | Coin | assets/art/pickups/coin.png | 16x16 (coin 6x8) | 4 spin | sprites/coin.tres | generated 2026-11-17 |
| C | Medkit / health potion | assets/art/pickups/health_pack.png | 16x16 | 1 | sprites/health_potion.tres | generated 2026-11-17 |
| C | Gravestone (cover) | assets/art/tiles/cover_gravestone.png | 16x16 | 1 | sprites/gravestone.tres, ruins_theme cover_tile | integrated: ruins_tiles_atlas.png slot (5, 0) = ruins_theme cover_tile (no separate file); sprites/gravestone.tres is still the Kenney picture |
| C | Gate with portal closed | assets/art/level/gate_closed.png | 48x32 | 1 | sprites/portal_closed.tres | generated 2026-11-17 (the placeholder is 16x16: the gate scene needs resizing) |
| C | Gate with portal open | assets/art/level/gate_open.png | 48x32 | 4 loop | sprites/portal_open.tres | generated 2026-11-17 |
| C | Portal open burst | assets/art/fx/portal_open.png | 32x32 | 5 | - | generated 2026-11-17 |
| C | Arena door seal (rubble) | assets/art/tiles/door_seal.png | 16x16 | 1 | - | generated 2026-11-17 |
| N | Spell shrine | assets/art/level/shrine.png, shrine_used.png | 16x24 | 4 glow; used 1 | sprites/shrine.tres, shrine_used.tres | generated 2026-11-17 |
| N | Falling-stone trap (shadow warning + rock + rubble) | assets/art/level/falling_stone.png | 16x16 | warn2/fall3/rubble1 | - | generated 2026-11-18 (see plan group 4) |
| N | Pillar (column hall template) | assets/art/level/pillar.png | 16x32 | 1 | - | generated 2026-11-17 |
| N | Crypt props (sarcophagus, broken statue, bones) | assets/art/level/sarcophagus.png, statue.png, bones.png | 32x16 / 16x24 / 16x16 | 1 each | - | generated 2026-11-17 |
| L | Skill-tree altar (hub before ruins) | assets/art/level/altar.png | 32x32 | 4 glow | - | generated 2026-11-18 (see plan group 2) |
| C | Wall torch (light accent, decorative) | assets/art/level/torch.png | 16x16 | 4 flicker | - | generated 2026-11-17 |

## Requested by gameplay code

Assets the code already uses with placeholders; integration = repointing the resource in the last column. Added by the gameplay session.

| P | Asset | File | Size | Frames | Code hook | Status |
|---|---|---|---|---|---|---|
| C | Static spikes (always up), ruins style; replaces the "Spikes" row below | assets/art/tiles/ruins_hazards.png (slot 1) | 16x16 | 1 | `level/ruins_theme.tres`: `hazard_texture` + `spikes_tile` | integrated |
| C | Timed spikes, one cell: animations `hidden`, `warn` (0.5 s warning), `rise`, `up` (hurts), `retract` | assets/art/tiles/spikes_timed_frames.tres | 16x16 | any count per animation; the code picks the frame from the phase progress (hidden 1.6 s, warn 0.5 s, rise 0.1 s, up 0.8 s, retract 0.2 s) | `level/spikes_timed.tres`: `frames` | integrated |
| C | Elite shield skeleton (all skeleton animations, shield on the leading side) | assets/art/enemies/skeleton_elite_frames.tres | 24x24 | as the skeleton | `actors/enemies/skeleton_shield.tres`: `sprite_frames` | integrated; the side the shield really blocks is shown by a faint arc drawn in code |
| C | Elite triple-shot archer | assets/art/enemies/archer_elite.png | 16x16 | 1 (still, like the archer) | `actors/enemies/archer_triple.tres`: `sprite` | integrated |
| C | Spawn warning ring (combat-room waves) | actors/effects/spawn_warning.tscn | 32x32 | 8 | `actors/enemies/spawn_marker.gd`: `look_scene` | integrated; the marker sets the ring's `z_index` to 0 after it is ready (at -1 the ring was drawn under the floor tiles) and puts itself first among the section's nodes, so the ring is above the floor and below the actors |
| N | Animation of the triple-shot archer (idle, walk, shoot), like the other enemies | assets/art/enemies/archer_elite_frames.tres | 24x24 | as the skeleton | `actors/enemies/archer_triple.tres`: `sprite_frames` | generated 2026-11-17 (archer strips recoloured: purple hood, gold eyes; tools/art/make_archer_elite.py) |
| C | Cracked wall (front and top) | assets/art/tiles/ruins_tiles_atlas.png slots (6, 0), (7, 0) | 16x16 | 1 each | `level/ruins_theme.tres`: `cracked_wall_tile`, `cracked_wall_top_tile` (the level draws `LevelGrid.cracked` cells with them) | integrated |
| C | Wall collapse | actors/effects/wall_collapse.tscn | 16x24 | 6 | `level/breakable_wall.gd`: `collapse_scene` | integrated |
| C | Nature theme (secret rooms, the glade) with the sunlit floor | level/nature_theme.tres | 16x16 | - | `level/level.gd`: `DEFAULT_REGION_THEMES` (`&"nature"`); `sunlit_floor_tile` (slot 6) under the light from above | integrated |
| C | Merchant and wandering merchant (idle), goods carpet | assets/art/characters/merchant_frames.tres, merchant_wander_frames.tres, assets/art/props/merchant_carpet.png | 24x24, 32x16 | idle 4 | `actors/npc/merchant.gd`: `frames`, `wandering_frames`, `carpet` | integrated |
| N | Light shaft from above (soft warm beam, bottom centre on the node) | assets/art/fx/light_shaft.png | 32x48 | 1 | `level/light_shaft.gd`: `texture` | generated 2026-11-18 (see plan group 4) |
| N | Shop screen: panel frame, item slots, healing icon | assets/art/ui/trade_panel.png, trade_slot.png, shop_icons.png (slot 0) | 24x24, 20x20, 16x16 | 1 | `ui/shop_screen.tscn` (frame), `ui/shop_screen.gd` (`slot_texture`), `assets/sprites/shop_heal_icon.tres` | integrated |
| C | Glade: open grass, sunlit patch with old slabs around it, props | nature_tiles_atlas.png slots (7, 0), (6, 0), (0-2, 0); assets/art/props/big_tree.png, broken_column.png | 16x16, 32x26, 16x24 | 1 | `level/glade_theme.tres` (`floor_tiles`, `sunlit_floor_tile`, `paved_floor_tiles`), `generation/glade.tres` (`props`) | integrated |

Check spike sprites with `tests/manual/spikes_preview.tscn` (saves the five phases side by side).

## Tilesets (per biome)

Biome 1 "Sandstone ruins" (core). Later biomes reuse the same layout: flooded ruins, jungle ruins (L).

| P | Asset | File | Size | Frames | Status |
|---|---|---|---|---|---|
| S | Floor base | assets/art/tiles/ruins_floor.png (col 0) | 16x16 | 1 | generated |
| C | Floor variants (cracks, moss, debris) x3 | assets/art/tiles/ruins_floor.png (cols 1-3) | 16x16 | 1 each | integrated: ruins_floor.png, ruins_floor_2.png, ruins_floor_3.png = ruins_tiles_atlas.png slots (0-2, 0); small details on top: floor_decals.png (generated 2026-11-17) |
| S | Wall (top + south front face) | assets/art/tiles/ruins_wall.png (col 0) | 16x16 | 1 | generated (hand-drawn, round 4: lighter top) |
| S | Wall top (no floor to the south: side walls, wall interiors) | assets/art/tiles/ruins_wall_top.png | 16x16 | 1 | generated (hand-drawn) |
| S | Floor variants 2 and 3 | assets/art/tiles/ruins_floor_2.png, ruins_floor_3.png | 16x16 | 1 each | generated (hand-drawn) |
| C | Wall variants x2 (brick, crumbled) | assets/art/tiles/ruins_wall.png (cols 1-2) | 16x16 | 1 each | partly: one brick wall (atlas slot (3, 0)) and the cracked wall (slots (6, 0), (7, 0)); no second plain brick variant |
| N | Wall autotile set (edges, corners) | assets/art/tiles/ruins_wall_set.png | 16x16 cells, 16-tile set (4x4) | - | generated 2026-11-18 (see plan group 4) |
| C | Pit top edge (rim) | assets/art/tiles/pit.png (col 0) | 16x16 | 1 | integrated: ruins_hazards.png slot 0 = ruins_theme pit_tile (tools/art/make_pit_tiles.py) |
| C | Pit inner | assets/art/tiles/pit.png (col 1) | 16x16 | 1 | integrated: ruins_hazards.png slot 7 = ruins_theme pit_inner_tile |
| N | Pit side/corner edges | assets/art/tiles/pit_edges.png (8 slots) | 16x16 | 1 each | generated 2026-11-18 (see plan group 4) |
| C | Spikes | assets/art/tiles/spikes.png | 16x16 | 3 (retracted, half, up) | integrated: static spikes ruins_hazards.png slot 1, timed spikes spikes_timed_frames.tres (see the table above) |
| L | Flooded ruins floor/wall/pit set | assets/art/tiles/flooded_*.png | 16x16 | as above | generated 2026-11-18 (see plan group 4) |
| L | Jungle ruins floor/wall/pit set | assets/art/tiles/jungle_*.png | 16x16 | as above | todo (the plan chose fire ruins instead, see plan group 4) |

## UI icons

| P | Asset | File | Size | Frames | Replaces | Status |
|---|---|---|---|---|---|---|
| C | Sword icon | assets/art/ui/icon_sword.png | 16x16 | 1 | sprites/sword_icon.tres | generated 2026-11-17 (tools/art/make_ui_icons.py) |
| C | Bow icon | assets/art/ui/icon_bow.png | 16x16 | 1 | sprites/bow_icon.tres | generated 2026-11-17 (tools/art/make_ui_icons.py) |
| C | Dash icon | assets/art/ui/icon_dash.png | 16x16 | 1 | sprites/dash_icon.tres | generated 2026-11-17 (tools/art/make_ui_icons.py) |
| C | Shield/block icon | assets/art/ui/icon_block.png | 16x16 | 1 | sprites/shield_icon.tres | generated 2026-11-17 (tools/art/make_ui_icons.py) |
| C | Coin icon (HUD) | assets/art/ui/icon_coin.png | 16x16 | 1 | - | generated 2026-11-17 (tools/art/make_ui_icons.py) |
| C | Heart / HP icon | assets/art/ui/icon_hp.png | 16x16 | 1 | - | generated 2026-11-17 (tools/art/make_ui_icons.py) |
| C | Weapon swap icon | assets/art/ui/icon_swap.png | 16x16 | 1 | - | generated 2026-11-17 (tools/art/make_ui_icons.py) |
| C | Pause icon | assets/art/ui/icon_pause.png | 16x16 | 1 | - | generated 2026-11-17 (tools/art/make_ui_icons.py) |
| C | Take / interact icon | assets/art/ui/icon_take.png | 16x16 | 1 | - | generated 2026-11-17 (tools/art/make_ui_icons.py) |
| C | Joystick base + knob | assets/art/ui/joystick.png | 48x48 + 16x16 | 1 | - | generated 2026-11-17 (joystick.png 48x48, joystick_knob.png; opaque, fade with modulate) |
| C | HP bar frame + fill | assets/art/ui/hp_bar.png | 64x8 | 1 | - | generated 2026-11-17 (hp_bar_frame.png + hp_bar_fill.png, both 64x8) |
| C | Rarity frames (common/rare/legendary) | assets/art/ui/rarity_frame.png | 18x18 x3 | 1 | - | generated 2026-11-17 (tools/art/make_ui_icons.py) |
| C | Menu/death-screen panel and button (9-slice) | assets/art/ui/panel.png, button.png | 16x16 9-slice each | 1 (button: normal/pressed) | - | generated 2026-11-17 (panel margins 4; button strip: normal, pressed) |
| C | Depth/section icon | assets/art/ui/icon_depth.png | 16x16 | 1 | - | generated 2026-11-17 (tools/art/make_ui_icons.py) |
| N | Parry, teleport skill icons | assets/art/ui/icon_{parry,teleport}.png | 16x16 | 1 | - | generated 2026-11-18 (see plan group 3) |

## Spell effects (later)

| P | Asset | File | Size | Frames | Status |
|---|---|---|---|---|---|
| L | Fireball (projectile + explosion) | assets/art/fx/fireball.png | 16x16 / 32x32 | 4 / 6 | integrated in another form: fire in three levels, fx/fire_l1-3.png + fire_trail.png in element_frames.tres (stage 26) |
| L | Ice wall | assets/art/fx/ice_wall.png | 16x32 | 4 | integrated in another form: fx/ice_l1-3.png, one picture per level (stage 26) |
| L | Whirlwind | assets/art/fx/whirlwind.png | 32x32 | 6 | integrated in another form: fx/wind_l1-3.png in element_frames.tres (stage 26) |
| L | Teleport | assets/art/fx/teleport_out.png, teleport_in.png | 32x32 | 5 each | generated 2026-11-18 (see plan group 3) |
| L | Stone shield | assets/art/fx/stone_shield.png | 32x32 | 4 | todo (no such spell in the game) |
| L | Fire tornado (combo) | assets/art/fx/fire_tornado.png | 32x32 | 6 | replaced by the fused spells of stage 26: firestorm, blizzard, steam (fx/*_l1-3.png in fusion_frames.tres) |
| L | Ice fortress (combo) | assets/art/fx/ice_fortress.png | 32x32 | 6 | replaced by the fused spells of stage 26 (see Fire tornado) |
| L | Spell icons x7 | assets/art/ui/spell_<name>.png | 16x16 | 1 | integrated: fx/element_icons.png (fire, ice, wind) and fx/fusion_icons.png (firestorm, blizzard, steam), 6 spells exist |

Generic FX (C): hit spark 16x16 x3, dust puff (dash/land) 16x16 x4, death poof 16x16 x4, pit fall 16x16 x3. Generated 2026-11-17: assets/art/fx/hit_spark.png, dust_puff.png, death_poof.png, pit_fall.png (16x16 strips, tools/art/make_world_props.py).

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
- Integrated in stage 26: `SpellData.frames` / `level_animations` / `level_textures` in `combat/spells/fireball.tres`, `whirlwind.tres`, `ice_wall.tres` (`fire_trail` from level 3: `FireballData.trail_animation`); spell icons `assets/sprites/*_icon.tres` are now regions of `element_icons.png`; level marks under the HUD spell icons (`Hud.level_pips`).

## Fused elements (art, 2026-11-14)

Pairs follow docs/design.md; each has 3 levels and looks stronger than the plain elements even on level 1 (more rings, a dense glowing core, two colour families). Files in assets/art/fx/, generator tools/art/make_fusion_frames.py, all in fusion_frames.tres (48x48, 4 frames, 12 fps, loop):
- firestorm_l1..3 = fire + wind (a burning whirlwind), blizzard_l1..3 = ice + wind (snow and ice shards), steam_l1..3 = fire + ice (a boiling cloud with hot drops). Level 3 adds a second, faster swarm on the outer ring.
- merge (32x32, 8 frames, 16 fps, plays once): two coloured sparks spiral in, a flash, the new element bursts out. Play it where the two spells merge.
- HUD icons: fusion_icons.png (16x16: firestorm, blizzard, steam); the level marks are the same level_pips.png as for the plain elements.
- If the combination table gets other pairs, add them to PAIRS in the generator (two colour ramps and a spark colour).
- Integrated in stage 26: `combat/spells/firestorm.tres`, `blizzard.tres`, `steam.tres` (frames and level animations; steam flies at half size and grows into its blast), icons `assets/sprites/firestorm_icon.tres`, `blizzard_icon.tres`, `steam_icon.tres` (regions of `fusion_icons.png`); `merge` plays on the player when the shop closes after a merge (`Game.MERGE_FRAMES`).

## Archer, beetle, Guardian (art, 2026-11-14)

PixelLab create_character (standard, 4 directions, high top-down, black outline), the same settings as the player and the skeleton; animations breathing-idle / idle and walking. Imported with `tools/art/import_pixellab.py` (palette snap, one box per strip, feet on the second-to-last row, attack / hurt / death made from the idle frames).
- Archer `a8d07376-4736-415d-86aa-b3bc3255f101`: a skeleton in a red hood and cloak with a bow and a quiver, 24x24, `archer_frames.tres`.
- Beetle `c0db1c8a-9c7c-43a4-87fb-1259f9e3a844`: a teal cave beetle, 16x16, `beetle_frames.tres`.
- Guardian `260f114c-e575-4167-974b-a405682eb00c`: a stone golem knight with glowing orange eyes and cracks, 64x64 canvas, `guardian_frames.tres`; `guardian.tscn` now uses an AnimatedSprite2D like the other enemies.
- In the game: `sprite_frames` of archer.tres, beetle.tres and guardian.tres. Animated art is drawn at its own size (sprite_scale is only for the old still pictures) with the feet just below the body's centre.

## Golem and ghost (art, 2026-11-17)

- Golem: PixelLab text prompts gave a dark robot and a white armoured figure (main mass in the floor's value range, or not a golem), so the front view was drawn in code from separate boulders (`tools/art/make_golem.py`, `assets/art/enemies/golem_reference.png`: light stone #d8d4c4 / #9aa2ad / #767a8c, moss on top, orange eye slits and core crack) and given to PixelLab v3 as the reference: character `9a0bd775-f2fa-4a67-88d7-a8bc64153934` "ruins_stone_golem_ref", 4 directions, 48x48; animations breathing-idle and walking-4-frames. Imported with `tools/art/import_pixellab.py <zip> golem assets/art/enemies 48 idle walk`. Then, once, `tools/art/finish_golem.py` (author's request): the golem is overgrown with grass, a grass strip on top of every stone and in the joints, blades over the outline on the head and shoulders, in the nature theme's greens (#8ac060 / #5a8a4a / #3b5a45).
- Ghost: PixelLab standard character `b78f55a6-efff-4075-b475-580f5ffb2e0b` "ruins_ghost" (4 directions, high top-down), animations breathing-idle (idle) and a v3 custom float (move). Imported with `tools/art/import_pixellab.py <zip> ghost assets/art/enemies 32 idle move`, then `tools/art/finish_ghost.py`: one teal body (the source's two pale tones had snapped to teal and bone) and its own death (white flash, rises and melts).
- Neither enemy exists in the game code yet (nice to have).

## Floor decals and lights (art, 2026-11-17)

| P | Asset | File | Size | Frames | Code hook | Status |
|---|---|---|---|---|---|---|
| C | Floor decals: pebbles, rubble, long crack, branching crack, puddle, moss, old bones, broken slab | assets/art/tiles/floor_decals.png (slots 0-7) | 16x16 each, transparent, no outline | 1 each | none yet: scatter a few per room on floor cells from the section RNG (purely visual, no collision) | generated |
| C | Light, stepped rings (the hero, bright magic) | assets/art/fx/light_banded.png | 128x128, white | 1 | none yet: PointLight2D texture; colour and energy in code | generated |
| C | Light for torches and the shrine | assets/art/fx/light_torch.png | 64x64, white, stepped | 1 | PointLight2D on assets/art/level/torch.png (warm colour, slight flicker) | generated |
| N | Smooth light, to compare | assets/art/fx/light_smooth.png | 128x128, white | 1 | - | generated |

- Decals use only floor-range colours (plus dim bone #767a8c and moss), so actors still pop. Drawn in `tools/art/make_world_props.py`.
- The lights are the only art with partial alpha (lights need a falloff); the stepped rings keep the pixel look.
- Readability with lights: in a mock-up with CanvasModulate about (0.32, 0.32, 0.42) an enemy outside the light almost disappears. Keep the ambient brighter, or keep actors readable another way (for example a light mask that leaves actors unshaded), and check on the phone that 60 FPS holds with a few lights.

## Plan group 1: golem and ghost, combat effects (stages 29-31, art 2026-11-18)

Drawn in `tools/art/make_combat_fx.py`. Strips are horizontal, frames left to right, no padding.

| P | Asset | File | Size | Frames | Direction / use | Status |
|---|---|---|---|---|---|---|
| C | Golem slam shockwave: dust ring with stone chunks running out over cracks in the floor | assets/art/fx/golem_shockwave.png | 64x64 per frame (384x64) | 6, one pass (12 fps) | none, round, centred on the golem; the ring reaches ~31 px, scale x1.16 for slam_radius 36 | generated |
| C | Golem slam warning: stippled dark shadow with a pulsing orange rim | assets/art/fx/golem_warning.png | 48x48 per frame (192x48) | 4, loop | none, round, centred; rim radius ~23 px, scale x1.5 for slam_radius 36 (replaces the circle of golem.gd _draw) | generated |
| N | Ghost fade in: teal sparks converge, a flickering column of light, a white flash ring | assets/art/fx/ghost_fade_in.png | 32x32 per frame (160x32) | 5, one pass | none; the column matches the ghost body (about 14x26, centred) | generated |
| N | Ghost fade out: flash ring, the column melts, sparks rise and scatter | assets/art/fx/ghost_fade_out.png | 32x32 per frame (160x32) | 5, one pass | none | generated |
| C | Damage digits 0-9 | assets/art/ui/damage_digits.png | cells 5x7 (3x5 glyph + 1 px outline), strip 50x7 | 10 glyphs, index = digit | white #f4f0e0, tint in code (crit, heal); place digits 4 px apart so the outlines overlap | generated |

## Plan group 2: camp at the entrance and progression (batch 7, art 2026-11-18)

Camp art in `tools/art/make_camp.py` (nature theme colours: grass #5a8a4a / #8ac060, warm stone #8a8466 / #6a6656 / #c8c088), UI in `tools/art/make_skill_ui.py`. Strips are horizontal, frames left to right.

| P | Asset | File | Size | Frames | Direction / use | Status |
|---|---|---|---|---|---|---|
| C | Camp tiles: 0-1 grass (1 with flowers), 2 dirt path, 3 path with grass, 4 pebbles on grass, 5 boulder on grass (cover, outlined), 6 cliff front (bottom row = contact shadow), 7 cliff top (grass over rock) | assets/art/tiles/camp_tiles_atlas.png | 16x16 slots, one row (128x16) | 1 each | same layout idea as ruins_tiles_atlas.png; tiles tile seamlessly except the cliff edges | generated |
| C | Entrance to the ruins: stone arch in a rock face, darkness inside, vines | assets/art/level/ruins_entrance.png | 48x32 | 1 | faces the viewer; the doorway is the arch opening (x 14-33, rows 8-28), threshold on row 29 | generated |
| C | Campfire: logs, ring of stones, flame | assets/art/level/campfire.png | 16x16 per frame (64x16) | 4, loop (8 fps) | none; pairs with light_torch.png | generated |
| C | Tent (A-frame, tan canvas, red pennant, guy ropes) | assets/art/level/tent.png | 32x32 | 1 | front face to the viewer, side roof to the right; ground shadow on row 29 | generated |
| C | Skill altar: stone pedestal, hovering golden rune ring with a star, sparks | assets/art/level/altar.png | 32x32 per frame (128x32) | 4, loop (6 fps), the ring bobs 1 px | faces the viewer | generated |
| C | Spell library shelf: books in many colours, a scroll, a violet orb | assets/art/level/spell_shelf.png | 32x24 | 1 | faces the viewer (stands against a wall or freely) | generated |
| C | Skill tree node frame: locked (grey stone), available (dim gold), bought (bright gold, sparkling corners) | assets/art/ui/skill_node.png | 20x20 per state (60x20) | 3 states, index 0-2 | the 16x16 perk icon goes inside at (2, 2); the inside is transparent | generated |
| C | Skill tree connection line: inactive (grey), active (gold) | assets/art/ui/skill_line.png | 8x6 per state (16x6) | 2 states | 9-slice / stretch horizontally (margins 0 left/right, the 6 px height stays); rotate 90 deg for vertical links | generated |
| C | Skill tree panel background | assets/art/ui/skill_panel.png | 24x24 | 1 | 9-slice, margins 8 (gold corners) | generated |
| C | Perk icons: 0 health+, 1 damage+, 2 speed+, 3 skill cooldown-, 4 healing+, 5 coin magnet, 6 armour, 7 chest luck, 8 third spell slot, 9 starting coins | assets/art/ui/perk_icons.png | 16x16 each (160x16) | 10, index as listed | green "+" badge (nature green) on boosts, blue "-" on the cooldown, no badge on 5-7 | generated |

## Plan group 3: skills and weapons (batch 8, art 2026-11-18)

Icons, weapons and effects in `tools/art/make_weapons_skills.py`; player strips from PixelLab with `tools/art/import_player_weapons.py` (animation ids in its docstring). Rarity accents: common steel, rare blue, legendary gold.

| P | Asset | File | Size | Frames | Direction / use | Status |
|---|---|---|---|---|---|---|
| C | Parry icon: crossed blades with a gold spark | assets/art/ui/icon_parry.png | 16x16 | 1 | - | generated |
| C | Teleport icon: violet swirl with sparks | assets/art/ui/icon_teleport.png | 16x16 | 1 | - | generated |
| C | Parry flash: white-gold star, then a ring of sparks | assets/art/fx/parry_flash.png | 32x32 per frame (128x32) | 4, one pass (12 fps) | none, centred where the blow is parried | generated |
| C | Teleport out: flash ring, violet column, it melts, sparks rise | assets/art/fx/teleport_out.png | 32x32 per frame (160x32) | 5, one pass | none; the column matches the player body, a small ring on the floor at row 27 | generated |
| C | Teleport in: sparks converge, the column fills, flash ring | assets/art/fx/teleport_in.png | 32x32 per frame (160x32) | 5, one pass | none | generated |
| C | Spear common / rare / legendary | assets/art/weapons/spear_{common,rare,legendary}.png | 16x16 | 1 | diagonal, tip up-right; binding in the rarity colour (legendary: gold head glint) | generated |
| C | Daggers (a pair) common / rare / legendary | assets/art/weapons/daggers_{common,rare,legendary}.png | 16x16 | 1 | two crossed daggers; guards in the rarity colour | generated |
| C | Crossbow common / rare / legendary | assets/art/weapons/crossbow_{common,rare,legendary}.png | 16x16 | 1 | pointing right; limbs in the rarity colour | generated |
| C | Spear thrust streak | assets/art/fx/spear_thrust.png | 48x16 per frame (144x16) | 3 (start, full length with a tip spark, fading) | points right; the wielder is at the left edge, middle row (0, 8); rotate to the attack direction | generated |
| C | Dagger quick slash | assets/art/fx/dagger_slash.png | 32x32 per frame (96x32) | 3 (wind-up, full arc, fading) | points right, centred on the wielder, reach ~13 px, 100 deg; flip vertically for the other hand | generated |
| C | Crossbow bolt (short, steel head and fletching) | assets/art/weapons/crossbow_bolt.png | 16x16 | 1 | points right, tip at (14, 8) like arrow.png | generated |
| C | Player spear attack | assets/art/characters/player_spear_{down,up,right,left}.png | 24x24 per frame (96x24) | 4 (thrust and pull back) | 4 directions, feet and shadow like player_idle_<dir>; "up": the spear is drawn above the right shoulder | generated, not in player_frames.tres yet |
| C | Player dagger attack (two quick stabs) | assets/art/characters/player_daggers_{down,up,right,left}.png | 24x24 per frame (96x24) | 4 | 4 directions, as above | generated, not in player_frames.tres yet |

## Plan group 4: ruin styles by depth (batch 9, art 2026-11-18)

Styles in `tools/art/make_depth_styles.py` (built from the ruins tiles), extras in `tools/art/make_ruins_extras.py`, mini-boss from PixelLab with `tools/art/import_pixellab.py` + `tools/art/finish_bone_keeper.py` (ids and steps in its docstring).

Style atlases keep the ruins layout, so a new TileTheme only swaps textures: `<style>_tiles_atlas.png` slots 0-2 floor (0 plain, the common one), 3 wall front, 4 wall top, 5 cover, 6 cracked wall front, 7 cracked wall top, plus slot 8 = a wall front variant to mix with 3 (`wall_tiles = [Vector2i(3, 0), Vector2i(8, 0)]`); `<style>_hazards.png` slot 0 pit edge, 1 spikes, 7 pit inside, and slot 2 extra.

| P | Asset | File | Size | Frames | Direction / use | Status |
|---|---|---|---|---|---|---|
| C | Flooded ruins tiles: wet floor with puddles (slots 1-2), moss, wall with water running down (slot 8) | assets/art/tiles/flooded_tiles_atlas.png | 16x16 slots, 9 in a row (144x16) | 1 each | ruins layout + slot 8 | generated |
| C | Flooded hazards: 0 deep water edge (stone rim, water below), 1 spikes, 2 shallow water still frame, 7 deep water inside | assets/art/tiles/flooded_hazards.png | 16x16 slots (128x16) | 1 each | deep water works like a pit; shallow water is walkable (slows) | generated |
| C | Shallow water over the floor, ripples drifting right | assets/art/tiles/flooded_shallow.png | 16x16 per frame (64x16) | 4, loop (6 fps), tiles seamlessly | - | generated |
| C | Fire ruins tiles: basalt floor (embers on slots 1-2), dark basalt walls, glowing crack on slot 8 | assets/art/tiles/fire_tiles_atlas.png | 16x16 slots, 9 in a row (144x16) | 1 each | ruins layout + slot 8 | generated |
| C | Fire hazards: 0 lava edge, 1 spikes on basalt, 2 cooled crust (walkable, red seams), 7 lava inside | assets/art/tiles/fire_hazards.png | 16x16 slots (128x16) | 1 each (still frames of the animation) | lava works like a pit | generated |
| C | Lava animation: row 0 edge, row 1 inside | assets/art/tiles/fire_lava.png | 16x16 per frame (64x32) | 4 per row, loop (6 fps), tiles seamlessly | - | generated |
| C | Fire decals: glowing coals, ash, cooled splash, big ember | assets/art/tiles/fire_decals.png | 16x16 each (64x16) | 1 each | scatter like floor_decals.png | generated |
| N | Falling-stone trap: warning shadow (2), the rock falls (3), rubble (1) | assets/art/level/falling_stone.png | 16x16 per frame (96x16) | 6: warn 0-1, fall 2-4, rubble 5 | top-down, the shadow lies where the rock lands | generated |
| N | Pit edges and corners: 0 floor to the west, 1 east, 2 south, 3 north+west, 4 north+east, 5 south+west, 6 south+east, 7 north+south | assets/art/tiles/pit_edges.png | 16x16 slots (128x16) | 1 each | pit cells; with ruins_hazards slot 0 (floor to the north) and slot 7 (inside) | generated |
| N | Wall-top autotiles | assets/art/tiles/ruins_wall_set.png | 4x4 cells of 16x16 (64x64) | 16 | index = N + 2E + 4S + 8W, a bit set where that neighbour is not wall; cell (index % 4, index / 4) | generated |
| N | Light shaft from above (warm, stepped alpha like the light textures, dust motes) | assets/art/fx/light_shaft.png | 32x48 | 1 | bottom centre on the node | generated |
| N | Mini-boss Bone Keeper: big skeleton priest, violet robe, gold mitre, skull staff | assets/art/enemies/bone_keeper_<anim>_<dir>.png, bone_keeper_frames.tres | 48x48 per frame | idle 4, walk 4, attack 6 (wind-up frames 1-2), summon 6, hurt 2, death 4 | 4 directions; feet on row 46 in every strip | generated |

## Author's list 2026-11-21 (batch 10)

Order from the author: shard, obstacles and wall details, portal and free-standing gate, new boss, enemy attack wind-ups (these replace the red / orange warnings in the game, so the wind-up must read on its own).

### 1. Ruins shard (camp currency)

Generator `tools/art/make_shard.py`.

| P | Asset | File | Size | Frames | Centre / bottom | Status |
|---|---|---|---|---|---|---|
| C | Shard pickup: floating blue crystal, a glint runs down the facets, sparkles, the shadow glows blue on frames 1-2 | assets/art/pickups/shard.png | 16x16 per frame (64x16) | 4, loop (8 fps) | crystal centre (7.5, 7), shadow row 14 = ground, same as coin.png | generated |
| C | Shard HUD icon | assets/art/ui/icon_shard.png | 16x16 | 1 | centred, no shadow, like icon_coin.png | generated |

### 2. Room obstacles and flat wall details

Generator `tools/art/make_obstacles.py`. They replace the half-columns and statues against the walls (`level/level_decor.gd` pillar / statue). Obstacles: the bottom row of the picture is the bottom of the cell the obstacle blocks (draw with the bottom-left corner on the cell's bottom-left; the picture rises above the cell); the base sits on the last rows with a #0f0e14 shadow under it, shifted 1 px right. Wall details: overlays on the brick front of `ruins_wall.png` (rows 6-14 only, nothing on the top face or outside the cell), placed on the same cell as the wall tile.

| P | Asset | File | Size | Frames | Centre / bottom | Status |
|---|---|---|---|---|---|---|
| C | Whole column: capital with top face, fluted shaft with a crack, plinth with moss | assets/art/level/obstacle_column.png | 16x32 (blocks 1 cell, rows 16-31) | 1 | centre x 7.5; plinth front rows 28-29, outline row 30, shadow row 31 | generated |
| C | Broken column: jagged break high on the left, a chip lying on the plinth | assets/art/level/obstacle_column_broken.png | 16x24 (blocks 1 cell, rows 8-23) | 1 | as the whole column, shadow row 23 | generated |
| C | Rock pile: four rocks lit from the top-left, moss between them | assets/art/level/obstacle_rocks.png | 16x16 (1 cell) | 1 | shadow rows 13-15 | generated |
| C | Sarcophagus: lid with a sword relief, front with carved panels | assets/art/level/obstacle_sarcophagus.png | 32x16 (2 cells side by side) | 1 | outline row 14, shadow row 15 | generated |
| C | Wall details: 0 crack, 1 hanging chain, 2 niche with a skull, 3 torn red banner with a gold emblem, 4 moss and ivy (torch stays `level/torch.png`) | assets/art/tiles/wall_details.png | 16x16 slots (80x16) | 1 each | overlay on the wall front cell, rows 6-14 | generated |

### 3. Boss portal and free-standing gate

Generator `tools/art/make_portal.py`. The boss portal replaces the arch in a wall after the boss; the free-standing gate is the arch of `gate_*.png` without the brick pillars at its sides, for arenas without a boss.

| P | Asset | File | Size | Frames | Centre / bottom | Status |
|---|---|---|---|---|---|---|
| C | Boss portal rising from the floor: 0 purple cracks in the floor, 1 the slabs break and fall in, the slot glows, 2-4 the stone frame rises out of the slot with dust, 5 it stands dark, 6 runes light up and a spark appears inside, 7 the glow spreads | assets/art/level/portal_rise.png | 32x48 per frame (256x48) | 8, once (10 fps), then portal_loop | front view; centre x 15.5, opening x 9-22 / y 11-41; base rows 42-45, outline row 46, shadow row 47 = floor | generated |
| C | Boss portal loop: purple light ripples out of the centre, runes pulse, sparks | assets/art/level/portal_loop.png | 32x48 per frame (128x48) | 4, loop (8 fps) | as portal_rise | generated |
| C | Free-standing gate, closed (dark spiral) | assets/art/level/gate_free_closed.png | 48x32 | 1 | arch centre x 23.5, threshold row 29, shadow row 31; footings x 7-15 and 32-40 | generated |
| C | Free-standing gate, open portal loop | assets/art/level/gate_free_open.png | 48x32 per frame (192x32) | 4, loop (8 fps) | as gate_free_closed; the opening burst stays fx/portal_open.png | generated |

### 4. New boss: Ruins Warden (replaces the Guardian of the Ruins)

A living marble statue: a hulking colossus, gold crown helmet, purple eyes and glowing cracks, a round stone shield with a purple rune on its left forearm, a torn red sash. No weapon: it fights with the shield and its fists. PixelLab character `601be13f-5f28-4841-99d1-ce60ca3f1344` ("ruins_warden_boss_v3"); attacks, summon, roar, hurt and death are skeleton-v3 clips written pose by pose, so the wind-up poses are exact. Importer `tools/art/finish_warden.py <zip>` (steps and the PixelLab animation names in its docstring).

**Canvas 96x96, not 64x64**: the body is about 52 px tall (close to the 52x56 of the style guide), and the raised shield and the spread arms of the wind-ups need the room; at 64x64 they would be cut off or the boss would shrink to golem size. Feet centre at (48, 92) in every frame of every strip (lowest pixel on row 92), shadow rows 91-93. All strips share that point, so the sprite needs one offset for all animations. The wind-ups replace the red circles: hold the marked frames longer in code if a telegraph needs more time.

| P | Asset | File | Frames (96x96 each) | Wind-up / hit | Status |
|---|---|---|---|---|---|
| N | Idle (breathing) | assets/art/enemies/warden_idle_<dir>.png | 4, loop (6 fps) | - | generated |
| N | Walk (heavy steps) | warden_walk_<dir>.png | 6, loop (10 fps) | - | generated |
| N | Ground slam: shield and fist lifted overhead, then slammed down into a crouch | warden_slam_<dir>.png | 8 (10 fps) | wind-up 1-3 (arms overhead, hold 3), impact 4, crouch 4-6, recover 7 | generated |
| N | Boulder throw: picks a boulder off the floor, cocks it behind the head, hurls it | warden_throw_<dir>.png | 5 (10 fps) | pick-up 0-1, wind-up 2-3 (boulder overhead, hold 3), release 4 (spawn the projectile here) | generated |
| N | Circular wave: arms spread wide, knee up, stomp (stone debris ring on the floor) | warden_wave_<dir>.png | 8 (10 fps) | wind-up 1-3 (arms wide, knee up, hold 3), stomp 4, debris 5-6, recover 7 | generated |
| N | Summon: fist raised to the sky, trembling | warden_summon_<dir>.png | 6 (8 fps) | raise 1, hold 2-4 (spawn here), lower 5 | generated |
| N | Roar (going into phase 2): crouch with clenched fists, then bursts up, arms thrown wide | warden_roar_<dir>.png | 8 (10 fps) | crouch 0-3, burst 4-6 | generated |
| N | Hurt (recoil) | warden_hurt_<dir>.png | 4 (12 fps) | - | generated |
| N | Death: collapses forward onto its front | warden_death.png | 8 (10 fps), last frame held | - | generated |
| N | SpriteFrames with all of the above (names `<anim>_<dir>`, `death`) | assets/art/enemies/warden_frames.tres | - | - | integrated in stage 41 (guardian.tres: sprite_frames, feet_row 92) |

### 5. Enemy attacks with a readable wind-up

Generator `tools/art/make_enemy_windups.py` (PixelLab ids, steps and frame meanings in its docstring). They replace the attack strips that were the idle frame shifted with a slash drawn over it, so the red / orange warning tint can go: the wind-up pose itself says an attack is coming. The humanoids come from PixelLab skeleton-v3 clips on characters imported from the game's own idle frames (enlarged 2x, so the animation starts from the sprite the game shows), brought back to game size and snapped to the colours of the enemy's own idle and walk strips; feet on the idle's feet row in every frame, the idle's shadow under them. Elites are recoloured from the new strips as before. **Frame counts changed** (were 4), so attack timing in code may need a look: hold the wind-up frames longer if a telegraph needs more time.

| P | Asset | File | Frames | Wind-up / hit | Status |
|---|---|---|---|---|---|
| C | Skeleton: sword raised high behind the head, slash down (left view: strike frames 2-4 drawn by hand, the generated ones were smeared) | assets/art/enemies/skeleton_attack_<dir>.png | 6 (24x24) | wind-up 0-1 (hold 1), slash 2-3, recover 4-5 | generated |
| C | Shield skeleton (elite): the same, red armour, the shield stays where the idle has it | skeleton_elite_attack_<dir>.png | 6 (24x24) | as the skeleton | generated |
| C | Archer: bow up, draw to the cheek, release | archer_attack_<dir>.png | 6 (24x24) | bow up 0, draw 1-2 (hold 2), release 3 (spawn the arrow), recoil 4, lower 5 | generated; from the front the bow (hidden by the body in the generated frames) is drawn in front of the chest, its string pulled to the cheek on frames 2-3 |
| C | Triple-shot archer (elite): the same, purple cloth, gold eyes | archer_elite_attack_<dir>.png | 6 (24x24) | as the archer | generated |
| C | Beetle: crouches flat and pulls back, then lunges 3 px with open mandibles | beetle_attack_<dir>.png | 4 (16x16) | crouch 0-1 (hold 1), lunge-bite 2-3 | generated (drawn in code from the idle) |
| N | Golem: both fists rise over the head and hold, then slam the ground | golem_attack_<dir>.png | 8 (48x48) | rise 0, fists overhead 1-3 (hold 3), slam 4-5, recover 6-7 | generated; grass by finish_golem.py's overgrow |
| N | Ghost: pulls back with its arms raised, then reaches out | ghost_attack_<dir>.png | 6 (32x32) | pull back 0-1 (hold 1), reach and touch 2-3, back 4-5 | generated |
| C | SpriteFrames rewritten with the new attack lengths (other animations unchanged) | skeleton_frames.tres, skeleton_elite_frames.tres, archer_frames.tres, archer_elite_frames.tres, ghost_frames.tres, golem_frames.tres | - | - | generated |

## Batch 11 (stage 40, new element system)

Generator `tools/art/make_elements2.py`, in the style of `make_element_frames.py` / `make_fusion_frames.py` (no outline on effects, three looks per level, each bigger and richer). All animations are in `assets/art/fx/element2_frames.tres` (names = file names without .png, loop as noted). 12 fps unless noted.

| P | Asset | File | Size / frames | Anchor / use | Status |
|---|---|---|---|---|---|
| C | Water wave rolling forward (l2 taller, l3 tallest with spray) | assets/art/fx/water_l{1,2,3}.png | 48x32, 4, once | caster at the left edge, middle row (y 16); points right, rotate in code | generated |
| C | Water turning to ice at level 3: frost burst over the same arc, shards break off on the last frame | assets/art/fx/ice_burst_l3.png | 48x32, 4, once | as water_l3 | generated |
| C | Ice crust over a frozen enemy (ice at the feet, icicles at the sides, middle open) | assets/art/fx/frozen_mark.png | 16x16, 1 | centred on the enemy, bottom row = feet | generated |
| C | Stone spike breaking out of the floor: 0 cracks, 1 tip with dust, 2 full, 3 cracking, 4 rubble (l3 with a glowing seam) | assets/art/fx/stone_spikes_l{1,2,3}.png | 16x24, 5, once | floor row 22, shadow row 23, centre x 8; spawn several in a line | generated |
| C | Drops falling from a wet enemy | assets/art/fx/wet_drops.png | 8x8, 4, loop (8 fps) | over the enemy's head | generated |
| C | Plasma orb, violet-white with a short tail and crackling sparks | assets/art/fx/plasma_l{1,2,3}.png | 16x16 (l3 24x24), 4, loop | flies right; orb centre (size/2 + 2, size/2) | generated |
| C | Lava pool flat on the floor, bubbles and drifting crust (l3 with embers) | assets/art/fx/lava_pool_l{1,2,3}.png | 48x48, 4, loop (8 fps) | centre (24, 24); radius 11 / 15 / 19 px (flattened 0.62) | generated |
| C | Lightning bolt: bright, branching, fading | assets/art/fx/lightning.png | 64x16, 3, once | from (0, 8) to (63, 8): stretch and rotate between two points | generated |
| C | Lightning hit: flash, ring, sparks | assets/art/fx/lightning_hit.png | 16x16, 3, once | centred where the bolt lands | generated |
| C | Vines growing out of the floor in a ring: soil cracks, sprouts, leaves, curls (l2 gold buds, l3 thorns and red flowers) | assets/art/fx/vines_l{1,2,3}.png | 48x48, 5, once, hold the last | centre (24, 24); ring radius 15 / 18 / 21 px (flattened 0.6) | generated |
| C | Sand ring around the caster with dust (l3 with stones), like wind_l* | assets/art/fx/sandstorm_l{1,2,3}.png | 48x48, 4, loop | centred on the caster | generated |
| N | Volcanic lightning: the bolt in gold and red-orange | assets/art/fx/volcanic_lightning.png | 64x16, 3, once | as lightning.png | generated |
| N | Storm cloud with flashes (frames 1 and 3, a short bolt under it) and rain | assets/art/fx/storm_cloud.png | 48x32, 4, loop (8 fps) | above the player, cloud centre (24, 13) | generated |
| N | Meteor: a burning rock falling, flame teardrop above it | assets/art/fx/meteor.png | 32x32, 4, loop | rock centre (16, 21); move it down in code | generated |
| N | Meteor shadow growing on the floor (red rim on the last two frames) | assets/art/fx/meteor_shadow.png | 32x32, 4, once | centre (16, 16), where the meteor lands | generated |
| N | Meteor impact: flash, fire ring with a column, smoke and thrown rocks, crater | assets/art/fx/meteor_impact.png | 64x64, 5, once | centre (32, 36) = impact point | generated |
| C | Element icons: water, stone_spikes, plasma, lava, lightning, vines, sandstorm, volcanic_lightning, storm_cloud, meteor | assets/art/ui/element_icons2.png | 16x16 slots (160x16) | same frame as fx/element_icons.png (1 px outline) | generated |
| C | Player crossbow attack: aim, shot, recoil (from behind the crossbow is hidden, the tips of its steel limbs show beside the body and kick up on the shot) | assets/art/characters/player_crossbow_{down,up,right,left}.png | 24x24, 4 (96x24) | 4 directions, feet and shadow like player_idle_<dir> (as player_spear_*); right / left: the crossbow is held like a rifle, raised a little on frames 0-2 and lowered on 3; importer `tools/art/import_player_crossbow.py` (PixelLab groups in its docstring) | integrated in stage 40 (player_frames.tres, crossbow.tres attack_animation) |

Integrated in stage 40: `combat/spells/water.tres` (water_l1, water_l2, ice_burst_l3), `stone_spikes.tres`, `plasma.tres`, `lava.tres` and `meteor.tres` (lava_pool_l*), `vines.tres`, `sandstorm.tres`, `lightning.tres` / `volcanic_lightning.tres` (bolt + lightning_hit), `storm_cloud.tres`, meteor fall / shadow / impact in `SpellZone`; wet_drops and frozen_mark on enemies (`Enemy.status_frames`, `frozen_mark`); icons `assets/sprites/<spell>_icon.tres` from element_icons2.png. Player crossbow attack: in player_frames.tres. The warden and the enemy wind-ups: integrated in stage 41 (EnemyData.attack_strike_frame; warnings removed).

## Batch 12 (stage 42: floor styles with their own enemies, a better shop)

Drawn in code: `tools/art/make_batch12.py`. The drowned and the ember imp come from PixelLab: `tools/art/import_batch12_enemies.py` (character ids and steps in its docstring; attacks made like batch 10 group 5). Enemy strips are `<enemy>_<anim>_<dir>.png` plus one `<enemy>_death.png`, with `<enemy>_frames.tres` (animations `<anim>_<dir>` and `death`; idle 6 fps, walk 10, attack and hurt 12, death 10). **Strike frame**: the code holds the wind-up frames until the blow and plays the rest from the strike frame. No elites.

| P | Asset | File | Size / frames | Wind-up / strike, anchor | Status |
|---|---|---|---|---|---|
| C | Warden's boulder: rolling marble chunk, purple glint in a crack that turns with the roll, dust behind | assets/art/fx/warden_boulder.png | 16x16, 4, loop | flies right, centre (8, 8) | generated |
| C | Boulder hit: dust ring and stone chips flying out and falling | assets/art/fx/warden_boulder_hit.png | 24x24, 4, once | centre (12, 13) | generated |
| C | Drowned: bloated corpse with pale sickly green-yellow skin and dead white eyes, rotten cloth, seaweed (second pass: the bone-white skin read as a skull) | assets/art/enemies/drowned_{idle,walk,attack,hurt}_<dir>.png, drowned_death.png, drowned_frames.tres | 24x24; idle 4, walk 6, attack 6, hurt 2, death 5 (collapses into a puddle) | attack: arms reach back and up 0-1 (hold 1), **strike 2** (lunge and grab), 3 holds the grab, 4-5 back; feet row 22, shadow row 23 | generated |
| C | Tide crab: stone-grey shell with barnacles, red-orange claws and legs | assets/art/enemies/tide_crab_{idle,walk,attack,hurt}_<dir>.png, tide_crab_death.png, tide_crab_frames.tres | 16x16; idle 4, walk 4 (sideways scuttle), attack 4, hurt 2, death 4 | attack: claws raised over the shell, opened 0-1 (hold 1), **strike 2** (snap forward), 3 back; shell bottom row 13, shadow row 14 | generated |
| C | Flooded decals: puddle, seaweed, shells, shallow puddle with a ripple | assets/art/tiles/flooded_decals.png | 16x16 each (64x16) | scatter like fire_decals.png | generated |
| C | Ember imp: small horned charcoal imp with glowing cracks, floats (body 2 px over its shadow) | assets/art/enemies/ember_imp_{idle,walk,attack,hurt}_<dir>.png, ember_imp_death.png, ember_imp_frames.tres | 24x24; idle 4 (bob and flicker), walk 4, attack 6, hurt 2, death 5 (bursts into embers) | attack: hands up, a fireball grows over the head 0-2 (hold 2), **strike 3** (throw: spawn imp_fireball here), 4-5 follow-through; feet row 20, shadow row 23 | generated |
| C | Imp fireball | assets/art/fx/imp_fireball.png | 8x8, 4, loop | flies right, core (5, 4) | generated |
| C | Magma beetle: the beetle with a basalt shell and lava seams, same feet and size as beetle_* | assets/art/enemies/magma_beetle_{idle,walk,attack,hurt}_<dir>.png, magma_beetle_death.png, magma_beetle_frames.tres | 16x16; idle 4, walk 4, attack 4, hurt 2, death 4 (cracks open, lava spills) | attack: crouch 0-1 (hold 1), **strike 2** (bite), 3 back | generated |
| C | Shop goods icons: whetstone (a sword drawn over a stone on a wooden base, sparks), dice, heart elixir, lucky charm, rune key | assets/art/ui/shop_icons2.png | 16x16 each (80x16) | same frame as shop_icons.png; region x = index * 16 | generated |
| C | Merchant sign for the glade: post with a hanging board and a gold coin, red pennant | assets/art/props/merchant_sign.png | 16x24, 1 | bottom row 23 (shadow), post at x 6-7 | generated |
| N | Depth banner plates: ruins (purple runes), flooded (water line, drips), fire (basalt, lava sparks) | assets/art/ui/floor_plates.png | 64x16 each, stacked (64x48) | plain middle x 12-51, y 5-10 for the title text | generated |

## Title screen (batch 13, part 6)

Generators `tools/art/make_title.py` (logo) and `tools/art/make_menu_background.py` (background and flames), 32-colour palette plus the camp's nature colours.

| P | Asset | File | Size / frames | Anchor / use | Status |
|---|---|---|---|---|---|
| C | "RUINS" logo: blocky carved stone letters with a front face, cracks, moss, purple runes cut in and a purple glow | assets/art/ui/title_logo.png | 160x48, 1 | centre it at the top of the menu (e.g. top-left at (240, 24)) | generated |
| C | Menu background (second take): striped retro sun setting behind an aqueduct, rays and clouds lit from below, far mountains with a stepped temple, ruined towers rimmed with sunset light, mist; on the right the ruins gate in a strong purple light (the author's pick): a ruined wall with ivy that crumbles away right of the gate (the sunset shows behind it), pilasters with torches, purple runes in the arch stones, a tunnel going down (receding arches, steps) towards a bright purple doorway far below with a halo and rays, the stone, wall and ground in front lit purple in fading rings, mist over the threshold and sparks; on the left the camp: an A-frame canvas tent (flaps tied back, guy ropes), backpack, log seats, the fire pit with its warm light; cobbled path, dark foreground bushes and grass, a vignette; the upper middle stays calm for the logo | assets/art/ui/menu_background.png | 640x360, 1 | full screen; generator tools/art/make_menu_background.py (called by make_title.py) | generated |
| C | Campfire flames for the background | assets/art/ui/menu_fire.png | 32x32, 3 (96x32), loop 8 fps | draw at (180, 284) on the background (the fire's base is at (196, 312)) | generated |

Integrated in stage 42: warden_boulder(+_hit) in `actors/projectiles/stone.tscn`, drowned / tide_crab / ember_imp / magma_beetle frames in `actors/enemies/<id>.tres`, imp_fireball in `actors/projectiles/imp_fireball.tscn`, flooded_decals in `level/flooded_theme.tres`, shop_icons2 in `shop/shop.tres` (ShopData.goods_icons). Not used yet: floor_plates.png, merchant_sign.png.

## Audio (batch 13)

PixelLab's sound and music tools need a tier 2 subscription; the author chose CC0 packs instead (Kenney audio packs and Juhani Junkala's retro sound effects and chiptunes, list and links in `assets/audio/CREDITS.md`). Every file is built by `tools/audio/make_audio.py` (recipe per file: source clips, layering, speed, filters; usage in its docstring) with one treatment so the packs sound like one game: retro, a little muffled (low-pass), a short stone-room reflection, silence trimmed at both ends, a short fade-out. Sound effects: OGG Vorbis, mono, 44.1 kHz, peak -1 dBFS (footsteps -12 dBFS), 0.1-1.2 s (loops, the roar, the Warden's death and thunder up to 3 s). Music: OGG Vorbis, stereo, 44.1 kHz, -14 LUFS, true peak under -1 dBFS; each loop is the whole file, repeated to 60-120 s, filtered and echoed across the seam so the end joins the start (play it with looping on). Variants `<name>_1.._3`: pick one at random.

| P | File | Length | What it is for | Status |
|---|---|---|---|---|
| C | assets/audio/sfx/sword_swing_1.ogg | 0.14 s | sword swing (pick one of the variants at random) | generated |
| C | assets/audio/sfx/sword_swing_2.ogg | 0.14 s | sword swing (pick one of the variants at random) | generated |
| C | assets/audio/sfx/sword_swing_3.ogg | 0.16 s | sword swing (pick one of the variants at random) | generated |
| C | assets/audio/sfx/sword_hit_1.ogg | 0.45 s | sword hits an enemy | generated |
| C | assets/audio/sfx/sword_hit_2.ogg | 0.43 s | sword hits an enemy | generated |
| C | assets/audio/sfx/sword_hit_3.ogg | 0.53 s | sword hits an enemy | generated |
| C | assets/audio/sfx/heavy_slash.ogg | 0.42 s | third hit of the sword combo | generated |
| C | assets/audio/sfx/bow_draw.ogg | 0.50 s | drawing the bow (wooden creak) | generated |
| C | assets/audio/sfx/bow_release.ogg | 0.27 s | arrow released | generated |
| C | assets/audio/sfx/arrow_hit_flesh.ogg | 0.14 s | arrow hits an enemy | generated |
| C | assets/audio/sfx/arrow_hit_wall.ogg | 0.50 s | arrow hits a wall or cover | generated |
| C | assets/audio/sfx/crossbow_shot.ogg | 0.19 s | crossbow fires | generated |
| C | assets/audio/sfx/crossbow_reload.ogg | 0.65 s | crossbow reloads | generated |
| C | assets/audio/sfx/spear_thrust_1.ogg | 0.43 s | spear thrust | generated |
| C | assets/audio/sfx/spear_thrust_2.ogg | 0.51 s | spear thrust | generated |
| C | assets/audio/sfx/dagger_stab_1.ogg | 0.30 s | dagger stab (fast, short) | generated |
| C | assets/audio/sfx/dagger_stab_2.ogg | 0.33 s | dagger stab (fast, short) | generated |
| C | assets/audio/sfx/dagger_stab_3.ogg | 0.23 s | dagger stab (fast, short) | generated |
| C | assets/audio/sfx/crit_hit.ogg | 0.51 s | critical hit: a bright ring over the hit | generated |
| C | assets/audio/sfx/player_hurt_1.ogg | 0.19 s | the player takes damage | generated |
| C | assets/audio/sfx/player_hurt_2.ogg | 0.21 s | the player takes damage | generated |
| C | assets/audio/sfx/player_hurt_3.ogg | 0.11 s | the player takes damage | generated |
| C | assets/audio/sfx/player_death.ogg | 1.20 s | the player dies | generated |
| C | assets/audio/sfx/footstep_stone_1.ogg | 0.10 s | footstep on stone, very soft (peak -12 dBFS) | generated |
| C | assets/audio/sfx/footstep_stone_2.ogg | 0.10 s | footstep on stone, very soft (peak -12 dBFS) | generated |
| C | assets/audio/sfx/footstep_stone_3.ogg | 0.11 s | footstep on stone, very soft (peak -12 dBFS) | generated |
| C | assets/audio/sfx/footstep_stone_4.ogg | 0.11 s | footstep on stone, very soft (peak -12 dBFS) | generated |
| C | assets/audio/sfx/dash.ogg | 0.32 s | dash | generated |
| C | assets/audio/sfx/shield_block.ogg | 0.19 s | a hit blocked by the shield | generated |
| C | assets/audio/sfx/parry.ogg | 0.89 s | parry: metallic ring | generated |
| C | assets/audio/sfx/teleport_out.ogg | 0.90 s | teleport: vanish | generated |
| C | assets/audio/sfx/teleport_in.ogg | 0.90 s | teleport: appear (the vanish reversed) | generated |
| C | assets/audio/sfx/weapon_level_up.ogg | 0.76 s | weapon level up | generated |
| C | assets/audio/sfx/skeleton_swing.ogg | 0.18 s | skeleton sword swing | generated |
| C | assets/audio/sfx/bones_hit_1.ogg | 0.14 s | hit on a skeleton (bones clatter) | generated |
| C | assets/audio/sfx/bones_hit_2.ogg | 0.17 s | hit on a skeleton (bones clatter) | generated |
| C | assets/audio/sfx/bones_hit_3.ogg | 0.12 s | hit on a skeleton (bones clatter) | generated |
| C | assets/audio/sfx/skeleton_death.ogg | 0.56 s | skeleton collapses | generated |
| C | assets/audio/sfx/archer_release.ogg | 0.27 s | enemy archer shoots | generated |
| C | assets/audio/sfx/beetle_bite.ogg | 0.19 s | beetle bite | generated |
| C | assets/audio/sfx/beetle_swarm_loop.ogg | 2.00 s | beetle swarm skittering, seamless loop (soft, high-passed) | generated |
| C | assets/audio/sfx/golem_windup.ogg | 1.20 s | golem wind-up: stone grinding | generated |
| C | assets/audio/sfx/golem_slam.ogg | 1.20 s | golem ground slam | generated |
| C | assets/audio/sfx/ghost_wail.ogg | 1.20 s | ghost wail (no voice: an eerie tone) | generated |
| C | assets/audio/sfx/ghost_fade.ogg | 0.38 s | ghost fades in or out | generated |
| C | assets/audio/sfx/drowned_grab.ogg | 0.64 s | drowned grab (wet) | generated |
| C | assets/audio/sfx/crab_snap.ogg | 0.35 s | tide crab claw snap | generated |
| C | assets/audio/sfx/imp_cast.ogg | 0.70 s | ember imp throws its fireball (fire whoosh) | generated |
| C | assets/audio/sfx/magma_hiss.ogg | 1.00 s | magma beetle hiss / lava | generated |
| C | assets/audio/sfx/enemy_spawn.ogg | 1.00 s | spawn warning before an enemy or a wave appears | generated |
| C | assets/audio/sfx/warden_roar.ogg | 2.60 s | Ruins Warden roar, phase 2 (low rumble, no voice) | generated |
| C | assets/audio/sfx/warden_slam.ogg | 1.20 s | Warden ground slam | generated |
| C | assets/audio/sfx/warden_throw.ogg | 0.80 s | Warden throws the boulder | generated |
| C | assets/audio/sfx/boulder_hit.ogg | 0.89 s | the boulder lands | generated |
| C | assets/audio/sfx/warden_summon.ogg | 1.20 s | Warden summons | generated |
| C | assets/audio/sfx/warden_death.ogg | 3.00 s | Warden crumbles | generated |
| C | assets/audio/sfx/fireball_cast.ogg | 0.70 s | fireball cast | generated |
| C | assets/audio/sfx/fireball_explode.ogg | 1.00 s | fireball explodes | generated |
| C | assets/audio/sfx/water_wave.ogg | 1.20 s | water wave | generated |
| C | assets/audio/sfx/ice_freeze.ogg | 0.18 s | ice / freeze | generated |
| C | assets/audio/sfx/whirlwind_loop.ogg | 2.00 s | whirlwind, seamless loop | generated |
| C | assets/audio/sfx/stone_spikes.ogg | 0.77 s | stone spikes break out of the floor | generated |
| C | assets/audio/sfx/steam_burst.ogg | 1.00 s | steam burst | generated |
| C | assets/audio/sfx/plasma_shot.ogg | 0.33 s | plasma orb shot | generated |
| C | assets/audio/sfx/lava_bubble_loop.ogg | 1.60 s | lava pool bubbling, seamless loop | generated |
| C | assets/audio/sfx/lightning_strike_1.ogg | 0.90 s | lightning strike | generated |
| C | assets/audio/sfx/lightning_strike_2.ogg | 0.90 s | lightning strike | generated |
| C | assets/audio/sfx/vines_grow.ogg | 0.46 s | vines grow | generated |
| C | assets/audio/sfx/sandstorm_loop.ogg | 2.50 s | sandstorm, seamless loop | generated |
| C | assets/audio/sfx/thunder_rumble.ogg | 2.80 s | storm cloud thunder | generated |
| C | assets/audio/sfx/meteor_fall.ogg | 1.20 s | meteor falling (whistle) | generated |
| C | assets/audio/sfx/meteor_impact.ogg | 1.20 s | meteor impact | generated |
| C | assets/audio/sfx/spell_fusion.ogg | 1.03 s | two spells merge (magic chime) | generated |
| C | assets/audio/sfx/coin_pickup_1.ogg | 0.42 s | coin picked up | generated |
| C | assets/audio/sfx/coin_pickup_2.ogg | 0.13 s | coin picked up | generated |
| C | assets/audio/sfx/shard_pickup.ogg | 0.21 s | ruins shard picked up (glassy) | generated |
| C | assets/audio/sfx/health_pickup.ogg | 0.79 s | health potion picked up | generated |
| C | assets/audio/sfx/chest_open.ogg | 0.91 s | chest opens | generated |
| C | assets/audio/sfx/chest_locked.ogg | 0.46 s | chest is locked | generated |
| C | assets/audio/sfx/gate_open.ogg | 1.20 s | gate / arena door opens (stone) | generated |
| C | assets/audio/sfx/portal_enter.ogg | 1.20 s | entering the portal | generated |
| C | assets/audio/sfx/secret_wall_break.ogg | 1.20 s | secret wall breaks | generated |
| C | assets/audio/sfx/spikes_out.ogg | 0.37 s | spikes come out | generated |
| C | assets/audio/sfx/pit_fall.ogg | 0.82 s | falling into a pit | generated |
| C | assets/audio/sfx/shop_buy.ogg | 0.72 s | buying in the shop | generated |
| C | assets/audio/sfx/shop_denied.ogg | 0.10 s | not enough coins / denied | generated |
| C | assets/audio/sfx/ui_click.ogg | 0.14 s | button click | generated |
| C | assets/audio/sfx/ui_open.ogg | 0.31 s | a menu or panel opens | generated |
| C | assets/audio/sfx/ui_close.ogg | 0.31 s | a menu or panel closes | generated |
| C | assets/audio/sfx/banner.ogg | 1.20 s | short sting when a floor style or the arena starts | generated |
| C | assets/audio/sfx/death_sting.ogg | 2.28 s | game over sting (sound effect) | generated |
| C | assets/audio/music/menu_camp.ogg | 75.3 s | menu and camp: calm (Stage Select, slowed 0.85, muffled, echo); seamless loop (the whole file); -14.1 LUFS | generated |
| C | assets/audio/music/ruins_explore.ogg | 102.9 s | ruins floors: quiet (Stage 1, slowed 0.8, muffled, echo); seamless loop (the whole file); -14.0 LUFS | generated |
| C | assets/audio/music/flooded_explore.ogg | 66.0 s | flooded floors: watery, echoing (Stage 2, slowed 0.85, long echo); seamless loop (the whole file); -14.0 LUFS | generated |
| C | assets/audio/music/fire_explore.ogg | 82.7 s | fire floors: tense (Level 2, slowed 0.88, muffled); seamless loop (the whole file); -14.0 LUFS | generated |
| C | assets/audio/music/combat.ogg | 81.9 s | combat rooms and the arena: faster (Level 3); seamless loop (the whole file); -14.0 LUFS | generated |
| C | assets/audio/music/boss_warden.ogg | 78.0 s | Ruins Warden fight: heavy (Boss Fight, slowed 0.92); seamless loop (the whole file); -14.0 LUFS | generated |
| C | assets/audio/music/glade_merchant.ogg | 74.3 s | merchant's glade: gentle, a little cheerful (Level 1); seamless loop (the whole file); -14.0 LUFS | generated |
| C | assets/audio/music/death_jingle.ogg | 5.2 s | after death, plays once (the Ending's opening, slowed, fading out); not a loop; -14.0 LUFS | generated |

Integrated in stage 42 part 3: portal_rise / portal_loop as the exit of every section (`level/gate.tscn`; the old gate_closed/open and gate_free_* are no longer used), obstacle_column / obstacle_column_broken / obstacle_rocks / obstacle_sarcophagus and wall_details in `level/ruins_theme.tres`, pickups/shard.png and ui/icon_shard.png, props/merchant_sign.png (`generation/glade_data.gd`), ui/floor_plates.png (HUD banner), ui/menu_background.png, menu_fire.png, title_logo.png (main menu). Not used yet: falling_stone, pit_edges, ruins_wall_set, flooded_shallow, bone_keeper_*, icon_hp / icon_depth / icon_swap / rarity_frame, training_dummy, light_banded / light_smooth, death_poof, ice_l1-3, sarcophagus.png.

## Batch 14 (placeholders and floor styles)

Generators: `tools/art/make_batch14.py` (everything but the player poses; the dummy's frames come from `dummy_frames()` in `tools/art/make_world_props.py`) and `tools/art/import_player_cast_parry.py` (PixelLab v3 animations of the player character, see its docstring). 32-colour palette only; 1 px #08070b outline on UI, objects and actors, none on tiles; light from the top-left.

| P | Asset | File | Size / frames | Anchor / use | Status |
|---|---|---|---|---|---|
| C | Round stone touch button: normal (top disc 3 px above its dark side) and pressed (disc sunk, stone one step darker); the sunken face (radius ~16) holds a 32 px icon | assets/art/ui/touch_button.png | 48x48 x 2 (96x48): normal, pressed | attack and skill buttons; the face centre is (24, 22) normal, (24, 24) pressed: move the icon down 2 px when pressed | generated |
| C | Small stone touch button, same look (2 px side) | assets/art/ui/touch_button_small.png | 32x32 x 2 (64x32): normal, pressed | swap, take, pause, spell buttons; face centre (16, 15) normal, (16, 16) pressed | generated |
| C | Cooldown ring over the 48 px button's rim: gold filling clockwise from 12 o'clock over a dark groove, white leading edge | assets/art/ui/touch_cooldown.png | 48x48, 8 frames (384x48) | same rect as the unpressed touch_button; frame i = (i + 1) / 8 charged, frame 7 = full (ready); pick floor(progress * 8) clamped to 0-7 | generated |
| C | Joystick base: a ring of carved stone blocks round a dark recess, a faint inner circle, four purple direction notches | assets/art/ui/touch_joystick_base.png | 96x96, 1 | centred on the base (radius 48, drawn 1:1 by `touch_joystick.gd`) | generated |
| C | Joystick knob: lighter stone cap standing 3 px high, purple rune in the middle | assets/art/ui/touch_joystick_knob.png | 40x40, 1 | centred on the knob (knob_radius 18 + 1 px outline; the cap centre is 1-2 px above the image centre) | generated |
| C | Weapon card frame: dark stone border lit from the top-left, 1 px gold inner line, chamfered corners with gold studs, flat #1f1e29 inside | assets/art/ui/card_frame.png | 24x24, 1 | 9-slice, 6 px margins on all sides (edges are constant along their length); modulate with the rarity colour | generated |
| C | "YOU FELL" plate: carved stone letters like the title logo, cracks, a red glow | assets/art/ui/death_plate.png | 160x32, 1 | top of the death screen | generated |
| C | Death screen illustration: the hero's sword stuck in the floor with the red scarf tied to the hilt, before the open portal that lights the floor purple; dark corners, 1 px frame | assets/art/ui/death_art.png | 96x64, 1 | under the plate (opaque picture) | generated |
| C | "PAUSED" plate: letters raised on a dark stone slab, purple glow, rune studs at both ends | assets/art/ui/pause_plate.png | 128x24, 1 | top of the pause menu | generated |
| C | Flooded cover: the ruins column with wet streaks, coral on the capital and the base, barnacles, weed, water round the plinth | assets/art/level/flooded_obstacle_coral_column.png | 16x32, 1 | like obstacle_column: bottom-left on the cell, rises one cell above it | generated |
| C | Flooded cover: barrel with iron hoops, barnacles and weed, a puddle round it | assets/art/level/flooded_obstacle_barrel.png | 16x16, 1 | like obstacle_rocks: one cell | generated |
| C | Flooded cover: wrecked boat hull, bow to the left, stern broken off with ragged planks and two bare ribs, a hole in the side, puddle | assets/art/level/flooded_obstacle_boat.png | 32x16, 1 | like obstacle_sarcophagus: two cells side by side | generated |
| C | Fire cover: two basalt prisms (a tall one and a short one in front) with glowing cracks, embers at the foot | assets/art/level/fire_obstacle_basalt_column.png | 16x32, 1 | like obstacle_column | generated |
| C | Fire cover: cooled lava rock, dark crust with hot seams | assets/art/level/fire_obstacle_lava_rock.png | 16x16, 1 | like obstacle_rocks | generated |
| C | Fire cover: sunken brazier, an iron bowl of coals with a flame on a stone foot sunk into broken floor plates | assets/art/level/fire_obstacle_brazier.png | 16x24, 1 | bottom-left on the cell, rises half a cell above it | generated |
| C | Flooded wall details: 0 dripping water, 1 hanging seaweed, 2 barnacles, 3 rusty grate with water behind, 4 glowing shell | assets/art/tiles/flooded_wall_details.png | 16x16 x 5 (80x16) | like wall_details.png: overlays on the wall front, rows 6-14 only; region x = index * 16 | generated |
| C | Fire wall details: 0 glowing crack, 1 red-hot chain, 2 soot stain, 3 small lava drip, 4 charred banner | assets/art/tiles/fire_wall_details.png | 16x16 x 5 (80x16) | like wall_details.png | generated |
| C | Flooded wall light: lantern hanging from an iron bracket, cold blue-green light that flickers, a few glow specks | assets/art/level/flooded_lantern.png | 16x16, 4 frames (64x16), loop 8 fps | like torch.png (same cell and light position); light colour teal #2aa8a0 | generated |
| C | Fire wall light: iron brazier bowl on the wall with tall flames | assets/art/level/fire_brazier.png | 16x16, 4 frames (64x16), loop 8 fps | like torch.png; light colour #e09a20 | generated |
| C | Flooded door rubble: wet rocks, water and weed in the gaps | assets/art/tiles/flooded_door_seal.png | 16x16, 1 | like door_seal.png | generated |
| C | Fire door rubble: basalt blocks with lava glowing in the gaps | assets/art/tiles/fire_door_seal.png | 16x16, 1 | like door_seal.png | generated |
| C | Player cast: the free hand comes up, a purple glow at it, then lowers | assets/art/characters/player_cast_{down,up,right,left}.png | 24x24, 4 frames (96x24), 12 fps once | like player_attack_*: feet on row 22, shadow row 23; frame 0 = wind-up, the spell leaves on frame 1 (glow on frames 1-2) | generated |
| C | Player parry: the blade comes up and is held across the body (up: horizontal behind the head; right/left: upright in front), a white-gold flash on the blade on frame 1 | assets/art/characters/player_parry_{down,up,right,left}.png | 24x24, 3 frames (72x24), 12 fps once | like player_block_*; frame 1 (the second) = the parry moment with the flash; hold frame 2 while the parry window lasts | generated |
| C | Seaweed grip: strands rising round the legs and curling in, a wrap round the shins, drops falling | assets/art/fx/grip_seaweed.png | 16x8, 4 frames (64x8), loop 8 fps | over the player while slowed by the drowned; bottom row on the player's feet row (row 22 of the 24x24 frame), centred: offset (4, 15) in the player frame | generated |
| C | HUD status icons: 0 slowed (a boot wrapped in weed), 1 rune key held, 2 lucky charm active, 3 sure critical hit ready (sword with gold sparks) | assets/art/ui/status_icons.png | 12x12 x 4 (48x12) | region x = index * 12 | generated |
| C | Training dummy: idle, then two hit frames that wobble on the post (top bent 2 px away from the blow, then swinging 1 px back past the middle) while straw flies off | assets/art/enemies/training_dummy.png | 24x24, 3 frames (72x24): idle, hit, hit | hit = frames 1-2 at 12 fps, then back to frame 0 | generated |

## Batch 15 (boss chest, elemental Wardens)

Drawn in code: `tools/art/make_batch15.py` (chest and effects), `tools/art/make_elemental_wardens.py` (the two Wardens, recoloured from warden_* so the silhouette, the frame counts and the wind-up / strike frames are the same as in the Warden table above; extra colours in docs/art-style.md "Elemental Wardens"). Parts 3-5 (fungal and sand styles, sound) are not made yet.

| Prio | What | File | Size / frames | Anchor / notes | Status |
| --- | --- | --- | --- | --- | --- |
| C | Boss chest: dark stone, gold straps and rim, purple runes, gold lock plate | assets/art/pickups/chest_boss.png | 24x24, 4 (96x24): closed, lid ajar (light leaks out), open (gold and purple glow), open with a flash | bottom row 22, shadow row 23 | generated |
| C | Tide Warden: wet green-grey marble, corals and shells on the shoulders, barnacles, seaweed sash, teal eyes and cracks, drops | assets/art/enemies/tide_warden_{idle,walk,slam,throw,wave,summon,roar,hurt}_<dir>.png, tide_warden_death.png | 96x96, frames and fps as warden_* | feet (48, 92); the shield and the held boulder are recoloured with the body (green stone, no separate water ball in the hands) | generated |
| C | Tide Warden geyser: fist raised with water gathering round it, then palms slammed into the floor in a crouch | assets/art/enemies/tide_warden_geyser_<dir>.png | 96x96, 8 (10 fps) | wind-up 1-3 (hold 3), **impact 4** (splash at the hands), 5-7 back; feet (48, 92); poses: warden summon 0-3 + slam 4-7 | generated |
| C | SpriteFrames of the Tide Warden (`<anim>_<dir>`, `death`, `geyser_<dir>`) | assets/art/enemies/tide_warden_frames.tres | - | idle/walk loop | generated |
| C | Molten Warden: black basalt, lava in the cracks, orange eyes, sparks | assets/art/enemies/molten_warden_{idle,walk,slam,throw,wave,summon,roar,hurt}_<dir>.png, molten_warden_death.png | 96x96, frames and fps as warden_* | feet (48, 92); the shield is basalt with lava cracks like the body (no separate red-hot colour, see the generator) | generated |
| C | Molten Warden meteor: both arms up, a fireball grows over the hands and is thrown up | assets/art/enemies/molten_warden_meteor_<dir>.png | 96x96, 8 (10 fps) | wind-up 1-3 (fire grows, hold 3), **throw 4** (fireball leaves the top of the frame), 5-7 back; poses: warden slam 0-3-0 | generated |
| C | SpriteFrames of the Molten Warden (`<anim>_<dir>`, `death`, `meteor_<dir>`) | assets/art/enemies/molten_warden_frames.tres | - | idle/walk loop | generated |
| C | Water orb (Tide Warden's throw) | assets/art/fx/water_orb.png | 16x16, 4, loop | flies right, centre (8, 8) | generated |
| C | Water orb burst: splash crown, drops, ends as a puddle | assets/art/fx/water_orb_burst.png | 32x32, 5, once | centre (16, 18); spawn tide_puddle after it | generated |
| C | Tide puddle zone: dark water, bright rim, ripples | assets/art/fx/tide_puddle.png | 32x32, 4, loop | centre (16, 16), reach 14 x 10 px | generated |
| C | Geyser warning: ripples and bubbles on the floor | assets/art/fx/geyser_warn.png | 16x16, 4, loop | centre (8, 9) | generated |
| C | Geyser: water column from the floor up | assets/art/fx/geyser.png | 16x32, 6, once | bottom on row 31, centre x 8; full height on frames 2-3 | generated |
| C | Tide ring: water wave ring (like golem_shockwave) | assets/art/fx/tide_ring.png | 64x64, 6, once | centre (32, 32), ring radius 6 ... 30 | generated |
| C | Molten boulder: basalt with turning lava cracks, sparks behind | assets/art/fx/molten_boulder.png | 16x16, 4, loop | flies right, centre (8, 8) | generated |
| C | Lava crack pool: cracks with lava after the impact | assets/art/fx/lava_crack_pool.png | 32x32, 7 (224x32) | 0-3 loop (lava pulses), 4-6 cooling once; centre (16, 16) | generated |
| C | Molten ring: fire wave ring with embers, scorched cracks | assets/art/fx/molten_ring.png | 64x64, 6, once | centre (32, 32), ring radius 6 ... 30 | generated |

Integrated in stage 45: chest_boss.png (`actors/pickups/chest_boss.tscn`), tide_warden_* and molten_warden_* (`actors/enemies/tide_warden.tres`, `molten_warden.tres`), water_orb / water_orb_burst (`actors/projectiles/water_orb.tscn`), molten_boulder (`molten_boulder.tscn`), tide_puddle / lava_crack_pool (frames 0-3) / geyser_warn / geyser (`assets/art/fx/boss_fx_frames.tres`, built by `tools/art/make_boss_fx_frames.py`), tide_ring / molten_ring (shockwave). Not used: lava_crack_pool cooling frames 4-6 (the patch fades out instead).

Integrated in stage 46 (autoload `Sound`, ids = file names without `_N`): every sfx of batch 13 except beetle_swarm_loop, lava_bubble_loop, spikes_out, death_sting, ui_click (loops, per-tile spikes and menu clicks are left for later); all 8 music tracks.
