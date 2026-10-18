# Editor workflow — D28 (2026-10-11)

Latest user choices: resource keys must work; explain editable values in Chinese;
retain world AI for the 5s countdown, freeze during battle; roll every1s, species
configurable, arrival does not guarantee admission; separate unit data, shared art;
reduce unnecessary decoration wrappers. These supersede D24's one-roll policy.

## Data / interfaces

- SkillDefinition.default_key is the default source, refreshed by register_skill.
  Explicit game-menu overrides alone win. schema2 settings save overrides only;
  legacy generated skill defaults are not treated as intentional remaps.
  Settings "跟隨資源" removes one override. Do not reset the artist's blast key.
- Selected visible skills determine shortcut eligibility. Duplicate selected skill
  keys or command collisions report a conflict, never silently choose a hidden skill.
  Immediate blast keeps D17 semantics; other manual skills retain D11 confirmation.
- Chinese export documentation describes units, probabilities and ownership; the
  skill key editor is a native Inspector EditorProperty with native Undo/Redo.
- Data folders: mercenaries / monsters / summons / layouts. Art is unchanged.
  UnitResourcePaths rewrites known legacy definition_path/representative_path only.
  Never rewrite unknown resource names, unit IDs, XP, equipment or receipts.

## Countdown / transitions

- Only the initial clicked party is admitted at start. Every1000ms ACTIVE nearby
  parties may roll approach chance, using their representative species override
  or their habitat's rules. Stable ID order, independent persistent encounter RNG.
- Every approach requires a complete legal CHASE route. Provisional !/RESERVED
  is not admission. On physical arrival within configured distance (default48),
  legal unobstructed segment and available capacity, roll join chance. A miss
  hesitates and can retry after1s. Pending notice limit8, final limit4 batches/60.
- Deadline releases nonparticipants; snapshots/power only contain admitted teams.
  Existing token/checkpoint/settlement ownership remains unchanged.
- COUNTDOWN updates ordinary AI/spawn timers. Unrelated monsters cannot acquire
  another encounter. LOADING/IN_BATTLE freezes world; battle has its own clock.
- GameDirector hides new render_root until actors and camera are ready. A persistent
  SceneTransitionCover holds the last ready rendered frame through loading, resets
  camera smoothing/scroll before reveal, and retains that frame across retries.
  One frame read per transition, not per-frame capture. BGM is unchanged.

## Native single-Sprite decoration

- Pure scenery is Sprite2D with native Texture/Region/Offset/Transform, metadata
  stable ID and optional hover definition. Menu/template creates the same form.
- Foot position is the Sprite origin; Offset shifts artwork without moving sort
  anchor. Snapshot/compiler derive visual data from the actual native Sprite.
- New/duplicated editor nodes get unique IDs; Undo/Redo keeps the assigned identity.
  Runtime presentation can still use WorldSceneryView; no claim of one-node runtime.
- Entrances/landmarks retain logic author nodes + Artwork. Regions and calibrated
  TileMap layers are not flattened. Scenery never changes navigation masks.
- One-shot migration backups and hashes live in artifacts/editor-workflow-2026-10-11.
  Do not rerun migration helpers against an artist's ongoing edits.
- User approved only lake SpawnZones/Position_3 capacity60→54, position/layout fixed.

## Verification

editor_workflow_core_suite, editor_workflow_data_suite, dynamic_reinforcement_suite,
multi_party_suite; real editor --editor-workflow-smoke sandbox; default run_all,
--all and non-headless world/movement_regression. Evidence and known failures in
docs/editor_workflow_validation.md. Manual mouse acceptance remains separate.
