# EmacEArt village integration

The three existing monkey encounter IDs now reference `features/monkey/village_easy.tscn`, `village_hard.tscn`, and `village_mania.tscn`. The original garden remains available for regression tests. No encounter IDs, settlement authority, rewards, companion stats, or save schemas changed.

## Editing

Open the wrapper scene for a difficulty. `Environment` instances `village_environment.tscn`, a flattened copy of the author's complete `Slavica Free 2026 Version.scn`. Building/terrain/prop transforms are retained. Do not regenerate it from the one-shot inspection scripts after manual edits.

`LevelLayout` owns PlayerSpawn, Monkeys/Monkey0..4, each monkey's route markers, IntroCamera, global bounds, activity bounds, water height and intro yaw. Full world bounds protect against falling off the terrain; activity bounds only constrain escape choices. Difficulty Resources keep the existing 180/120/90 second limits and speed settings.

The navigation mesh was baked from static collision with radius 0.45 m, height 1.7 m, climb 0.4 m, slope 42 degrees, cells 0.3 x 0.2 m. Escape choices must have a complete path. The high monkey uses an existing supported elevated surface at (5, 3.1, -11) and a collision-checked jump to (8, -0.04, -13). No floating platforms were added.

The 2026 demo did not instantiate the supplied water material. RiverSurface fills the existing low river basin at y=-1.65 using the author's EA_Water_Slavica material; its shader received the Compatibility NDC depth remap. Falling below -1.8 deals 10 HP and returns to the last safe point. There is no lava in this village.

## Source and license

See `features/monkey/assets/emaceart/SOURCE.md` and `LICENSE.txt`. The ZIP and untouched extraction are local under artifacts/monkey-village. Bundled EmacEArt Asset License allows modification and shipping inside games; standalone asset redistribution is prohibited. Do not describe it as CC0 or publish an independent asset archive. In-game pause menu has credits and an author-page link.

Converted unused files were reversibly archived under artifacts/monkey-village/unused-converted. Runtime dependency inventory is artifacts/monkey-village/runtime-dependencies.json (water dependencies were added subsequently). The original 48 MB download is not the Web transfer increment.

## Verification status

- Core capture: 18 passed / 0 failed.
- Difficulty: 18 passed / 0 failed.
- Encounter/settlement: 27 passed / 0 failed in Web build gates.
- Village: all three layouts have supported spawns and connected ground-monkey paths; high jump arc collision checks passed.
- Full project: 106 passed / 0 failed.
- Native Compatibility 1280x720, i9-13900K / NVIDIA RTX PRO 6000 Blackwell, three fixed viewpoints for 10 seconds each: 59.98 FPS. This is a powerful desktop, a capped static render measurement, not Web chase performance.
- Original and converted street screenshots compared; source placement retained.
- Actual Web game boot and cache reuse verified on isolated loopback origin.
- Three full Web capture victories, three entrance round trips, Web chase FPS and manual water/indoor-camera acceptance are still pending. Native suites do not substitute for these.

Known baseline: Godot shutdown reports ObjectDB/RID resource leaks after suites, despite assertion success. Embedded-browser fixed-size override caused a canvas scaling mismatch; browser acceptance must record actual viewport dimensions.

No production deployment.

## 2026-10-18 AI follow-up

User now owns further terrain/3D fixes. AI was strengthened with persistent perception memory, periodic look-back, cover-aware path scoring, burst recovery, delayed evasion and committed counterattacks. See artifacts/monkey-village/AI_VALIDATION.md for exact tuning and bounded evidence. New AI suite: 17/17; full Web pipeline: 15 gates passed, release fa1da701c2303dca3eff0c0e. Actual Web short chase sample: 57.26 FPS at 1280x720; three full-clear balance tests remain unverified.

One already verified collision fix is retained: RoadIsland_09a_PRE5/MeshCollider is disabled because it trapped the player against the underlying terrain. The visual mesh is unchanged. The navigation mesh was rebaked to 4377 polygons and is now linked as data/village_navigation.tres. No terrain subdivision was applied.
