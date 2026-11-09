# Ruins: tunnel roguelike with an AI director

Bachelor thesis project (Computer Science, AI). A top-down 2D roguelike for Android in which the player explores procedurally generated tunnels in ancient ruins, while an AI director adapts upcoming sections to how the player is doing. The research question: does adaptive generation (rule-based and learned director) keep players in a better difficulty range and feel more engaging than purely random generation?

Full design document: docs/design.md. Read it before any larger task.

## How to work with me

- Talk to me in Russian. Code, identifiers, comments and commit messages in English.
- I am learning Godot while building this and must be able to explain every part at my thesis defense. Explain what you changed and why, briefly, after each task. If you use a Godot concept I may not know (signals, Resources, autoloads, groups), explain it in one or two sentences.
- For anything bigger than a small fix: first propose a short plan (files to create or change, interfaces), wait for my OK, then implement.
- Work in small steps: one feature per task. Stop when the feature works; do not start the next one on your own.
- Do not edit .tscn / .tres files by hand without asking. I usually build scenes in the editor; you write scripts. If a scene change is needed, tell me what to add in the editor, or ask before editing the file.
- Do not add plugins, addons or new dependencies without asking.
- Do not change agreed interfaces (class names, signals, public methods, the log format) without saying so explicitly.
- After each task, tell me how to check it in the game (what to run, what I should see).
- If something in the design is unclear or contradicts itself, ask instead of guessing.

## Tech stack

- Godot 4.x (latest stable), GDScript 2.0. No C#.
- Target: Android, landscape. Renderer: Mobile or Compatibility. Must hold ~60 FPS on a mid-range phone.
- Virtual resolution 640x360, scaled to screen. Tiles 16x16.
- Placeholder art: free CC0 assets (Kenney). Final art is drawn by me or generated later; the code must not depend on specific sprites.
- Python 3 (outside Godot) only for training the learned director and analysing logs: training/.
- Godot 4 syntax only. Common mistakes to avoid: `export` instead of `@export`, `onready` instead of `@onready`, `KinematicBody2D` instead of `CharacterBody2D`, `move_and_slide(velocity)` with an argument, `yield` instead of `await`, `TileMap` instead of `TileMapLayer`.

## Code conventions

- Static typing everywhere: `var hp: int = 100`, `func take_damage(amount: int) -> void:`.
- snake_case for files, functions and variables, PascalCase for classes (class_name), UPPER_SNAKE_CASE for constants.
- Prefer signals for communication upward and between systems; call methods downward.
- Data-driven design: weapons, skills, spells, enemies and room templates are defined as custom Resource classes with parameters, not hard-coded in the player or enemy scripts. Adding a new weapon or spell should mean adding a new resource (plus a small effect script if needed).
- No magic numbers in gameplay code: tunable values live in resources or exported variables.
- All randomness comes from GameManager and is derived from one run seed: `GameManager.rng` for gameplay (damage spread, drops), `GameManager.make_section_rng(section_index)` for building a section. A section depends only on the run seed and its index, so combat never changes the tunnel. Same seed + same director decisions = same tunnel. This is required for experiments and debugging. Never use the global `randi()` / `randf()`.
- Keep scripts small and focused. One class per file.
- 2D physics layers: 1 world, 2 player, 3 enemies, 4 player_hurtbox, 5 enemy_hurtbox. Weapons find targets by hurtbox layer and check line of sight against the world layer.
- Damage always travels as a `DamageInfo` (amount, source node, source_id = weapon id or enemy type): attacker → `Hurtbox.receive_hit()` → `Health.take_damage()` → signals `damaged(info)` / `died(info)`. Telemetry relies on source_id.

## Game design summary (see docs/design.md for details)

- Run loop: before a run the player picks a starting weapon (sword or bow) and a basic skill (dash or shield block). The player goes through tunnel sections of 3-5 rooms, fights enemies, collects coins and health packs, opens chests. Each section ends at an ancient gate with a portal to the next section. Every 3-4 sections: a boss arena or strong wave. On death the run ends; coins are spent between runs on progression.
- Controls: virtual joystick on the left; attack button, basic-skill button and weapon-swap button on the right. Auto-aim towards the nearest enemy in a small radius.
- Weapons: sword (3-hit combo arc, last hit knocks back), bow (hold to draw, release to shoot, unlimited arrows; balanced by fire rate and draw time). Two weapon slots; picking up a third asks which to drop. Chests give better weapons with rarity.
- Basic skills (one chosen per run, cooldown-based): dash with short invulnerability, shield block, parry, short teleport. Core version: dash and block.
- Progression: permanent skills bought with coins between runs (small bonuses). Bought spells go into a pool; during a run the player picks one of three random spells from the pool at shrines or after bosses, 2-3 active spell slots. Certain spell pairs merge into a stronger spell (combination table as data).
- Enemies (each has a danger cost used by the director): skeleton guard (melee), archer (keeps distance), beetle swarm (fast, weak, in groups), stone golem (slow, tanky, telegraphed hit), ghost (passes through walls). Boss: Guardian of the Ruins. Behaviour via simple state machines + grid pathfinding (AStarGrid2D).

## Architecture

Three independent layers. The director never touches the scene tree directly; it returns a plan. This lets the director be tested without the game and swapped between modes.

- Gameplay: player, enemies, weapons, skills, pickups.
- Generation: builds a section from a plan (room templates + generated tunnels between them + placing content into slots), checks that the exit is reachable (BFS / A*), rebuilds if not.
- Director: reads player metrics and returns a SectionPlan (danger budget, room template choices, corridor width, enemy mix, number of health packs, chests and cover, spell offers).

Director interface, shared by all modes:

```gdscript
class_name Director
extends RefCounted

func choose_next(state: PlayerState) -> SectionPlan:
    return null
```

Modes: RandomDirector (control group), RuleDirector (rules and formulas, main director), LearnedDirector (contextual bandit trained offline on bot logs, parameters loaded from JSON; no ML libraries on the phone).

Planned layout (create folders as features need them). File names are snake_case; the class_name / autoload name inside stays PascalCase (game_manager.gd → GameManager):

```
res://
  autoload/      game_manager.gd (run state, seed, director mode), telemetry.gd (metrics, logs)
  director/      director.gd, random_director.gd, rule_director.gd, learned_director.gd,
                 section_plan.gd, player_state.gd
  generation/    room_template.gd, room_library.gd, section_builder.gd, tunnel_carver.gd
  rooms/         room templates
  actors/        player/, enemies/, projectiles/, pickups/
  combat/        weapons/, skills/, spells/ (Resource definitions + effect scripts)
  ui/            joystick, buttons, HUD, death screen, skill tree, survey
  main/          main.tscn
  tools/         bot_player.gd, simulate.tscn (headless bot runs for experiments)
training/        train_bandit.py, analyze.py (Python, outside Godot)
docs/            design.md, ai-usage-log.md
```

## Telemetry (thesis data)

Telemetry records metrics per section and appends one JSON line per section to `user://logs/<session>.jsonl`: session id, director mode, seed, section index, depth, budget, enemy mix, time, damage taken (total and per enemy type), HP on exit, kill ratio, weapon and skill usage, accuracy, idle time, death flag, estimated skill. Do not change the log format without telling me: the analysis scripts depend on it.

## Scope

- Core (must have for the defense): movement, basic skill (dash and block), sword and bow with start choice, two weapon slots, 3 enemy types, section generation, portal gates, rule-based director, random mode for comparison, telemetry logs, Android build.
- Nice to have: learned director and bots for simulation, 2 more enemy types, boss, progression and spells, own ruins tileset.
- If time remains: spell combinations, more weapons, several ruin styles by depth, sound and music.

Always build the core first. Do not implement nice-to-have features unless I ask.

## Testing

- After each task the project must open and run in Godot without errors in the Output panel.
- Logic that does not need the scene (director formulas, parsing room templates, BFS, spell combination table) should be testable headless, e.g. `godot --headless --script res://tests/<test>.gd` or with GUT if I add it.
- Generation: the same seed must produce the same section.

## AI usage log

I must document AI assistance for my thesis. After each larger task, append 2-3 lines to docs/ai-usage-log.md: date, task, what you generated, what I decided or changed.
