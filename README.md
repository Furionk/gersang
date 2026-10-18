# Gersang / 巨箱5.0

A Godot tactical RPG prototype combining isometric exploration, party management, RTS commands, direct-control action combat, orb matching, and 3D monkey-catching encounters.

**Project license: [MIT](LICENSE).** Use, modify, remix, and sell the project's original code and project-owned work, including in commercial or closed-source games. Keep the required copyright and permission notice. Third-party materials retain their own terms; read [credits and third-party notices](CREDITS.md) before reusing assets.

![The public checkout running the monkey-catching garden](docs/images/public-garden.png)

The game and many Inspector labels are currently in Traditional Chinese. This README is the English entry point. Gameplay balance, complete regression coverage, and mobile hardware acceptance are still in progress.

## Contents

- [Run the project](#run-the-project)
- [How the modules fit together](#how-the-modules-fit-together)
- [3D monkey-catching module](#3d-monkey-catching-module)
- [RTS module](#rts-module)
- [Isometric real-time action combat module](#isometric-real-time-action-combat-module)
- [Orb-matching puzzle module](#orb-matching-puzzle-module)
- [Shared systems and reuse](#shared-systems-and-reuse)
- [Validate changes](#validate-changes)
- [Export for the web](#export-for-the-web)
- [License and assets](#license-and-assets)

## Run the project

Use **Godot 4.7.1** with the **Compatibility** renderer.

```sh
git clone https://github.com/Furionk/gersang.git
cd gersang
godot --editor --path .
```

Replace `godot` with your Godot executable if it is not on `PATH`. Alternatively, import `project.godot` in the Godot Project Manager. Wait for the initial resource import, then press **F5** to run the full game.

Press **F6** with a supported world, battlefield, or preview scene open to run its isolated preview. The puzzle scene provides a temporary party model. Preview behavior is scene-specific; use the full game to verify encounter entry, settlement, and return.

Background music is optional and excluded from Git. Sound effects and unit voices remain available. Restricted EmacEArt village assets and their dependent scenes are also excluded; monkey encounters automatically use the included garden when those scenes are absent. Your local optional assets are preserved. See [installation and fallback behavior](docs/optional_assets.md).

## How the modules fit together

These are integrated gameplay systems within one Godot project. They share character definitions, encounter snapshots, health, progression, and result settlement.

| Module | Player experience | Main implementation | Main authoring data |
| --- | --- | --- | --- |
| 3D monkey catching | Control a catcher, use five gadgets, and capture persistent encounter targets. | [`features/monkey/`](features/monkey/) | `MonkeyProfile`, garden scene, habitat and party resources |
| RTS | Select several units and issue movement, attack, hold, and skill commands. | [`features/battle/`](features/battle/), [`features/units/`](features/units/), [`features/skills/`](features/skills/) | `UnitDefinition`, `SkillDefinition`, native battlefield scenes |
| Isometric real-time action combat | Directly control one party member while companions act independently. | [`features/rainbow/`](features/rainbow/) | `RainbowActionProfile`, weapon and enemy resources, boss tiers |
| Orb-matching puzzle | Drag orbs, build matches and combos, and attack while enemies keep their own timers. | [`features/puzzle/`](features/puzzle/) | `PuzzleRules`, unit elements, puzzle monster resources |

`GameDirector` coordinates the playable modes. `WorldSession` and `WorldContext` own persistent world state. `SettlementService` commits encounter results and rewards. UI and effects display events and issue commands; they do not award rewards independently.

A world encounter enters its countdown and uses its configured mode. `EncounterDefinition.monkey_profile` selects the 3D capture route. Eligible `action_profile` encounters use direct action control on a native battlefield. Ordinary encounters use RTS; a puzzle monster's attack can temporarily switch that battle into the orb-matching interface. Finishing the puzzle restores the underlying battle before normal encounter settlement.

## 3D monkey-catching module

### Play or preview

In the full game, find a monkey encounter in the river-bay world and approach its party. After the encounter countdown, the director transitions into the 3D scene. For a standalone preview, open [`features/monkey/garden.tscn`](features/monkey/garden.tscn) and press F6.

Capture every target before the encounter timer expires. A captured monkey keeps its original encounter unit ID, allowing the normal result system to identify defeated targets. Victory and retreat preserve the main character's remaining health; defeat uses the existing recovery flow. Companion health and mana are preserved from the entry snapshot. A timeout resolves as retreat rather than awarding capture victory.

| Input | Action |
| --- | --- |
| WASD | Move the catcher |
| Mouse | Turn the camera after pointer capture |
| Left mouse button | Use the equipped gadget |
| Right mouse button | Aim; also drag the camera when the fallback camera mode is enabled |
| Space | Jump, including the second jump |
| Ctrl | Sneak |
| 1–5 or mouse wheel | Equip a gadget |
| Q | Open the gadget wheel |
| Esc | Pause and release the pointer |

The gadget order is stun baton, capture net, radar, flying rotor, and speed hoop. Baton and net swing on a fresh press; radar, rotor, and hoop use held input. The net can capture without a prior stun. Its reach, height, facing, and obstruction checks determine whether a sweep connects.

In a browser, click the start or resume control to request pointer capture. If an embedded browser refuses capture, enable the right-button camera fallback in the pause panel. Arrow keys can adjust the camera in that mode.

### Edit difficulty and population

Open a [`features/monkey/data/`](features/monkey/data/) profile in the Inspector:

| Profile | Targets | Target level | Time limit |
| --- | ---: | ---: | ---: |
| `default.tres` | 5 | 1 | 180 seconds |
| `hard.tres` | 10 | 15 | 120 seconds |
| `mania.tres` | 15 | 35 | 90 seconds |
| `despair.tres` | 20 | 60 | 75 seconds |

[`MonkeyProfile`](features/monkey/monkey_profile.gd) exposes `run_speed`, `sneak_speed`, `net_reach`, `time_limit`, `sight_range`, `sight_degrees`, `hearing_range`, `confirmation_seconds`, `dodge_chance`, `dodge_reaction`, and attack timing. Change the existing Resource for a global tuning change, or duplicate it to create an independent difficulty.

For example, increase `time_limit` and reduce `confirmation_seconds` independently to allow a longer round with faster detection. Keep a nonzero dodge reaction if you want readable counterplay. These settings are tuning controls, not a guarantee that a difficulty is balanced.

**Shipped target counts come from encounter snapshots.** To change the population in an actual world encounter, also update its party template and `MemberRule` count/level ranges in the associated habitat resources. Changing `MonkeyProfile.monkey_count` alone changes the standalone fallback population, not an already-authored enemy party or an existing saved encounter.

### Edit the level, models, or integration

1. Duplicate `garden.tscn` for a new level and retain its `garden.gd` root script and `LevelLayout` structure.
2. Edit terrain, collision, and navigation in Godot. Keep the `PlayerSpawn` marker and the `Monkeys/Monkey0` through `Monkey4` home and route markers used by the current five behavior kinds.
3. Adjust [`MonkeyLevelLayout`](features/monkey/level_layout.gd) bounds, hazard settings, spawn placement, and route points. Rebuild navigation after changing walkable geometry and test stable-ground recovery.
4. Set the profile's `scene` to your scene. `resolved_scene()` uses the public garden if that scene is absent. Both encounter preload and final loading use the same resolution method.
5. Assign the profile to `EncounterDefinition.monkey_profile` in the relevant arena Resource, such as [`monkey_garden_arena.tres`](features/world/data/monkey_garden_arena.tres). Connect new world content through the existing habitat/arena authoring flow.

[`garden.gd`](features/monkey/garden.gd) owns catcher movement, tools, capture checks, hazards, and round state. [`monkey_actor.gd`](features/monkey/monkey_actor.gd) owns monkey behavior. [`meshy_presentation.gd`](features/monkey/meshy_presentation.gd) owns the current character clips and gadget attachments. Use that presentation layer to replace models without adding damage or capture logic to animation playback. Preserve the clip and attachment expectations when swapping assets.

The public garden and optional village have different geometry. Difficulty parameters carry across, but village route and balance conclusions do not automatically apply to the garden. See the historical [monkey guide](docs/monkey_garden.md) and current [optional-asset instructions](docs/optional_assets.md).

## RTS module

### Play and command a party

Start the full game and enter an ordinary monster encounter whose optional mode profiles are unset. Exploration and encounter countdown use the world system; actual unit commands run on the native battlefield.

| Input | Action |
| --- | --- |
| Left click or drag | Select a friendly unit or a group |
| Shift + selection | Add to the selection |
| Right click ground / enemy | Move / attack the selected target |
| M or A, then left click | Confirm a movement or attack/attack-move command |
| S / H | Stop / hold position |
| Tab | Select living friendly units |
| Skill key or icon, then left click | Prepare and confirm a targeted skill |
| Right click while aiming | Cancel the prepared command |
| Ctrl + group key, then group key | Store and recall a control group |
| X | Open the travel menu, or close the top open window |
| F1 | Toggle the window cursor guard |

The twelve control-group keys are `1`–`0`, `-`, and `=`. Settings can change bindings, and individual skills expose their own defaults. Some self-targeted skills explicitly opt into immediate activation; do not assume every skill uses the same confirmation behavior. Right-click a supported healing or supply skill icon to toggle its per-character autocast mode.

### Edit a unit or skill

1. Open an existing unit Resource in [`features/units/data/mercenaries/`](features/units/data/mercenaries/) or [`features/units/data/monsters/`](features/units/data/monsters/).
2. Tune its attributes, attack range, attack interval, movement speed, detection range, visual layout, or `skills` array. [`UnitDefinition`](common/data/unit_definition.gd) defines these fields; progression derives runtime stats from the definition, level, and character state.
3. To create a new species, duplicate the Resource and give it a new stable `id`. Keep an existing unit's ID when only changing that unit's balance or appearance.
4. Open or duplicate a [`SkillDefinition`](common/data/skill_definition.gd) Resource in [`features/skills/data/`](features/skills/data/). Set its target mode, trigger, mana cost, range, cast time, cooldown, damage formula, and effect data.
5. Add the skill to the intended unit's `skills` array. Use unique action IDs and check shortcut conflicts in the HUD/settings.
6. Register a new recruit or monster through the existing content-authoring resources. Editing a template does not grant a new character to an existing save or replace an already-persisted party automatically.

[`selection_controller.gd`](features/battle/selection_controller.gd) translates input into unit commands. [`tactical_unit.gd`](features/units/tactical_unit.gd) executes orders and autonomous behavior. [`features/skills/`](features/skills/) owns ability execution and effects; [`vitals.gd`](features/units/vitals.gd) owns unit health and mana. Keep mutable cooldowns, targets, and current health on runtime instances rather than shared `.tres` definitions.

### Build or reuse a battlefield

Duplicate a native scene such as [`features/battle/maps/meadow.tscn`](features/battle/maps/meadow.tscn). Edit `Terrain/Ground`, `Terrain/Walkable`, `Terrain/Blockers`, scenery, and the authored deployment markers. Assign the scene to `EncounterDefinition.battlefield_scene`; when that field is set, the native scene owns the layout instead of legacy procedural layout fields.

World maps and battlefields are separate assets. Wire a new arena and world habitat through the authoring system instead of changing only a display name. `WorldHabitat`, `SpawnProfile`, `PartyTemplate`, and `MemberRule` control the world population, composition, and level ranges.

For reuse, retain the shared unit, navigation, skill, progression, and encounter systems or explicitly replace those dependencies. Copying `features/battle/` alone does not produce a standalone RTS plugin. See the [content-authoring guide](docs/content_authoring_guide.md), [battlefield contract](specs/battlefield_scenes.md), and [combat controls](specs/combat_controls.md).

## Isometric real-time action combat module

### Play direct-control combat

The Rainbow Temple encounters use this mode. Control one existing party member directly; companions continue to follow, fight, and react to hazards. Switch characters through the roster, retain their actual health and equipment, and return through normal encounter settlement.

| Input | Action |
| --- | --- |
| Arrow keys | Move the controlled character |
| S | Melee attack |
| D | Ranged attack |
| Space | Guard |
| Hold A | Boost movement using BP |
| Tab or roster slot key | Switch the controlled party member |
| Esc | Retreat |

The action HUD also provides attack, guard, boost, and roster controls. Touch input uses a left movement stick and separate action buttons. Gamepad handling exists, but device-specific acceptance still needs testing. These controls are local to action encounters and differ from RTS command bindings.

### Understand the isometric coordinates

Both RTS and action combat keep gameplay positions in logical planar XY coordinates. [`common/iso.gd`](common/iso.gd) projects those positions for 2:1 presentation:

```gdscript
var screen_position: Vector2 = Iso.project(ground_position)
var ground_position_again: Vector2 = Iso.unproject(screen_position)
```

The projection is `screen = (x - y, (x + y) / 2)`. Screen-direction input is converted back into ground-space movement. Keep navigation, ranges, collision, and saved positions in the same logical coordinate system. Project only at presentation boundaries; do not store projected screen coordinates as world positions.

### Edit controls, attacks, and bosses

| Change | Edit |
| --- | --- |
| Acceleration, braking, boost, BP, guard, companion following, and feedback | [`features/rainbow/data/default_action.tres`](features/rainbow/data/default_action.tres), defined by [`RainbowActionProfile`](features/rainbow/action_profile.gd) |
| A character's weapon, artwork, attack timing, range, projectile count, spread, piercing, splash, and mana cost | [`features/rainbow/data/weapons/`](features/rainbow/data/weapons/), defined by [`RainbowWeaponDefinition`](features/rainbow/weapon_definition.gd) |
| Enemy pattern, body radius, warnings, armor, and exposure windows | [`features/rainbow/data/enemies/`](features/rainbow/data/enemies/), defined by [`RainbowEnemyDefinition`](features/rainbow/enemy_definition.gd) |
| Boss attack pools and tier behavior | `dragon_tier_0.tres` through `dragon_tier_3.tres` in [`features/rainbow/data/`](features/rainbow/data/) |
| Battlefield floor, barriers, deployment, and scenery | [`features/battle/maps/rainbow_temple.tscn`](features/battle/maps/rainbow_temple.tscn) |
| World entrances and monster regions | [`features/world/data/rainbow_temple.tscn`](features/world/data/rainbow_temple.tscn) |

For a new weapon, duplicate a weapon Resource, set `unit_id` to the matching stable unit definition ID, and include it in the action profile's `weapons` array. Adjust windup and recovery alongside power and range. Animation changes alone do not change authoritative attack timing.

[`action_battle.gd`](features/rainbow/action_battle.gd) coordinates control, AI, projectiles, and camera behavior. [`action_actor.gd`](features/rainbow/action_actor.gd) owns per-unit action state. [`temple_mechanics.gd`](features/rainbow/temple_mechanics.gd) and [`attack_schedule.gd`](features/rainbow/attack_schedule.gd) coordinate boss attacks and danger geometry. Keep telegraph shapes and damage checks consistent; HUD code must not apply a second hit.

### Enable the module for another encounter

1. Duplicate an action profile and configure its weapon and enemy mappings.
2. Add the intended world map ID to `allowed_maps`.
3. Assign the profile to the encounter's `action_profile`, following [`rainbow_temple_arena.tres`](features/world/data/rainbow_temple_arena.tres).
4. Provide the native battlefield and connect its arena to the world encounter.
5. Test character switching, companion behavior, hazards, retreat, and result persistence.

Both a configured profile and a matching snapshot return-map ID are required. This keeps action control scoped to authored encounters. Preserve `dispose()` cleanup of camera, collision, and controls when returning to RTS or exploration. The [Rainbow action guide](docs/rainbow_action.md) contains detailed mechanics and dated historical changes; check its newest section before using older tuning tables.

## Orb-matching puzzle module

### Play or preview

Open [`features/puzzle/puzzle_battle.tscn`](features/puzzle/puzzle_battle.tscn) and press F6 for an isolated preview with temporary allies and enemies. In the full game, encounter a puzzle monster: its first qualifying attack opens the puzzle interface while preserving the underlying battle.

The board contains **6 columns, 5 rows, and 5 orb types**. Hold an orb and drag it through adjacent cells to swap along the path. The movement timer starts on the first actual swap; releasing the orb resolves the board. Horizontal or vertical runs of at least three match, and falling orbs can add combos.

Fire, water, grass, and electric matches trigger attacks by corresponding party members; hearts heal surviving members. Click an enemy to choose a target. The displayed party health comes from actual participating character health; heart matches do not revive fallen members. Summons do not participate.

Enemy attacks use independent timers and continue during dragging, board resolution, and attack presentation. As soon as the board is stable, the next drag can begin without waiting for earlier attack or voice playback. Focus loss pauses the puzzle. Completing it transfers health and defeat changes back to the battle; it does not independently award the world encounter reward.

### Edit rules, enemies, and presentation

Open [`features/puzzle/data/default_rules.tres`](features/puzzle/data/default_rules.tres) in the Inspector. [`PuzzleRules`](features/puzzle/puzzle_rules.gd) exposes:

| Field | Use |
| --- | --- |
| `move_seconds` | Maximum drag duration after the first swap |
| `extra_orb_bonus`, `combo_bonus` | Additional matched-orb and combo multipliers |
| `heart_fraction` | Healing contribution from heart matches |
| `enemy_attack_fraction` | Enemy damage fraction relative to the participating party's maximum health |
| `enemy_initial_min_seconds`, `enemy_initial_max_seconds` | Initial attack-timer range |
| `enemy_cooldown_seconds` | Repeated enemy attack interval |
| `monster_attack_reference`, `monster_health_attack_multiple`, `monster_level` | Reference-based puzzle monster health calculation |
| `enemy_texture`, `dark_monster` | Optional enemy artwork and dark-monster presentation/rules flag |

For example, duplicate `default_rules.tres`, set `move_seconds` to `8.0` and `enemy_cooldown_seconds` to `12.0`, then assign that copy to the intended monster's `puzzle_monster` field. This changes that monster's rules without rewriting other enemies' shared Resource. Mixed encounters can contain enemies with different rule Resources.

To add a puzzle enemy, duplicate a suitable Resource under [`features/units/data/monsters/`](features/units/data/monsters/), assign a distinct `id`, choose its `puzzle_element`, and set `puzzle_monster` to a `PuzzleRules` Resource. Add it to a habitat party through the normal population authoring flow. For allied characters, set `puzzle_element` on their existing `UnitDefinition`; leave `puzzle_monster` empty unless the unit is intended to trigger puzzle combat as an enemy.

### Modify or reuse the puzzle implementation

| Responsibility | File |
| --- | --- |
| Seeded board generation, swaps, match groups, and gravity | [`puzzle_board.gd`](features/puzzle/puzzle_board.gd) |
| Damage, healing, element affinity, enemy timers, and outcome | [`puzzle_combat.gd`](features/puzzle/puzzle_combat.gd) |
| Drag lifecycle, resolution phases, and background action queues | [`puzzle_controller.gd`](features/puzzle/puzzle_controller.gd) |
| Board drawing, input presentation, and targeting | [`puzzle_view.gd`](features/puzzle/puzzle_view.gd) |
| Actual hit feedback | [`puzzle_impact.gd`](features/puzzle/puzzle_impact.gd) |
| Standalone preview and shared-battle integration | [`puzzle_battle.gd`](features/puzzle/puzzle_battle.gd) |

`PuzzleBoard` can be instantiated as a model with `PuzzleBoard.new()` and `initialize(seed)`. `PuzzleController.setup(allies, foes, rules, seed)` accepts arrays of character dictionaries; the existing preview in `puzzle_battle.gd` shows their `id`, `name`, `hp`, `max_hp`, `attack`, and `element` fields. Use that preview as the starting point for a separate puzzle screen rather than reproducing world-save logic inside the board.

Board dimensions are currently structural constants with matching assumptions in the controller and view. Changing only `WIDTH` or `HEIGHT` is insufficient; update cell bounds, input mapping, rendering, and tests together. Keep board readiness independent of attack/voice completion when modifying animation speed. The [puzzle guide](docs/puzzle_world.md) describes world integration and additional tower variants.

## Shared systems and reuse

- [`common/data/`](common/data/) defines shared Resource schemas. Native `.tres` and `.tscn` files are the authored content; documentation indexes are not runtime configuration.
- [`features/world/`](features/world/) owns world maps, habitats, persistent parties, encounters, navigation, and save coordination. [`features/progression/`](features/progression/) owns character progression, equipment, and roster state.
- The Autoload order is `GameSettings`, `PartyProgress`, then `WorldSession`, as configured in [`project.godot`](project.godot).
- Runtime health, cooldowns, orders, and actor state belong to instances. Do not mutate shared definitions to represent one wounded character or one active encounter.
- Stable content IDs and saved resource paths identify characters and populations. A new display name does not create a new species or migrate an old save.
- Many authoring scripts in `tools/` are one-shot provenance. Edit current scenes and Resources in the Inspector; do not rerun generators over authored content.

To extract a module into another project, start with its preview scene and follow its Resource, script, model, font, catalog, and Autoload references. Keep the `res://` layout during initial integration or migrate every reference and UID deliberately. Replace the world bridge explicitly if your host game uses different encounter and save systems.

Further reading: [content-authoring guide](docs/content_authoring_guide.md), [project architecture](docs/architecture/project_map.md), [resource policy](docs/architecture/resource_policy.md), [specifications](specs/index.md), and [developer instructions](AGENTS.md). Most existing detailed guides remain in Traditional Chinese.

## Validate changes

Import resources before running tests. Tests use isolated state/save paths; keep test scripts under `res://tests/` to preserve the project's isolation convention.

```sh
godot --headless --editor --path . --import
godot --headless --path . res://tests/background_music_suite.tscn
godot --headless --path . res://tests/public_checkout_suite.tscn
godot --headless --path . res://tests/entry_persistence_suite.tscn
godot --headless --path . res://tests/monkey_encounter_suite.tscn
```

`public_checkout_suite` specifically expects the public setup without music or village scenes. It is not the correct configuration check for a workstation with optional assets installed.

| Area changed | Relevant additional entry points |
| --- | --- |
| Monkey tools, AI, or round behavior | `tests/monkey_garden_suite.tscn`, `tests/monkey_difficulty_suite.tscn` |
| RTS commands or battlefield geometry | `tests/combat_ux_suite.tscn`, `tests/battlefield_scene_suite.tscn`, `tests/battlefield_alignment_suite.tscn` |
| Direct action combat | `tests/rainbow_action_suite.tscn`, `tests/rainbow_content_suite.tscn`, `tests/rainbow_boss_size_suite.tscn` |
| Orb matching and shared-battle restoration | `tests/puzzle_world_suite.tscn` |
| Movement, navigation, projection, or camera | `tests/world/movement_regression.tscn`, plus the applicable live-scene and rendered checks described in `AGENTS.md` |

For the initial public source snapshot on **2026-10-18**, a clean source-only checkout passed 14 BGM checks, 25 public-fallback checks, 25 entry/combat/disk-persistence checks, and 27 monkey encounter checks. The fallback garden was also rendered successfully. These are focused checks, not a complete gameplay, balance, browser, or mobile-device acceptance claim. Historical full regression and documentation-index issues remain documented separately.

Documentation changes should also verify links and Resource field names. Do not treat archived logs or old guide tables as proof of the current build.

## Export for the web

Open **Project → Tools → Web Export Studio** in Godot. Configure your own output directory and Godot executable before exporting with **Web Demo No BGM**. Existing local drive paths in export configuration must be adapted to your machine.

The plugin exports the native game, performs configured checks, and packages versioned SHA-256-verified chunks with download retries and caching. Upload the complete resulting release and its required files. This source repository is not itself a ready-to-serve GitHub Pages build.

See the [Web Export Studio guide](addons/web_export/README.md). Game-internal script or Resource changes require a new native export; editing the HTML shell alone does not update the game package.

## License and assets

The project's original code and project-owned work are **MIT licensed**: commercial use, modification, redistribution, sublicensing, and closed-source use are allowed subject to keeping the MIT notice. See [LICENSE](LICENSE).

Third-party code, fonts, models, recordings, and separately sourced artwork retain their respective terms. MIT does not grant rights over someone else's material. See [CREDITS.md](CREDITS.md) for notices and source-unverified assets, and [optional assets](docs/optional_assets.md) for installation instructions.

The public repository excludes `art/music/`, restricted EmacEArt assets and village scenes, `.godot/`, `artifacts/`, `build/`, credentials, and generated caches. Player saves live under Godot's `user://` location rather than in the repository. Do not commit excluded material when preparing your own fork or release.
