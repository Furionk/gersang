# D39 — Native content authoring foundation

User requests discoverable long-term editing of units/monsters, skills/effects, portraits, items, portals, terrain and non-fixed spritesheet frames. This extends D28/D33/D38; original gameplay/balance, save IDs, masks, artist layouts and protected movement stay intact.

- UnitDefinition, SkillDefinition/SkillEffectDefinition, GearItemDefinition and native map/battle scenes remain authority. Do not introduce a parallel editable CSV/JSON database.
- SpriteSheetLayout accepts arbitrary positive source columns/rows; output remains eight screen directions. Typed SpriteAnimationClip per action owns arbitrary source-column sequence, FPS, loop and positive relative frame durations. Unconfigured actions preserve exact legacy patterns/speeds. Full bounds, cardinality, timing and duplicate-action validation is retained, not disabled.
- Source Texture is preferred new native reference; legacy Sprite Path stays supported. Shared read-only definitions/frames are safe; per-character HP, cooldowns and released skill stats remain runtime instances/snapshots.
- Inspector additions are navigation/readonly preview/calculation, not a permanent authoring tab or a second runtime. Native editing/Undo/ResourceSaver remains authority. Only empty new layouts may initialize regular crop/pivot data via explicit native Undo action. Existing Rects/art are never auto-recut.
- Trial entries explicitly link friendly/enemy Resources; no filename inference. Formal initial lineup and unique species remain D38. New source data does not silently reroll existing saves.
- Existing Role-based art scale fallback is compatibility only; new content can set explicit Battle/World Sprite Scale. Do not change legacy visual appearance as a side effect of this schema update.
- `prepare_web_export.gd` is an explicit build step, dry-run by default. `--write-preset` derives a runtime allowlist from native files/references, excludes BGM/development assets and retains other preset settings. It never runs at boot or modifies maps/assets.

Validate content_authoring_suite, native editor sandbox, full regressions and rendered MOVE. Manual mouse review remains separate. This is authoring groundwork, not proof of competitive balance or removal of every legacy fixture/dispatcher.
