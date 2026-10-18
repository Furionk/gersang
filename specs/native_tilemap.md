# Native world TileMap contract — D18

**D20 supersedes the everyday editor/region workflow below:** see human_authoring.md. Six maps now use grouped native scenes; ground/obstacles/walkable/safe remain TileMap. Monster regions default to native Polygon2D; old masks only apply in explicit Tile Brush mode. No permanent authoring dock or custom canvas input. Native movement/navigation and detached placeholder validation are unchanged.

The user's native TileMap revamp supersedes polygon-only map authoring for the four existing maps. Godot 4.7.1 `TileMapLayer` / `TileSet` are canonical saved scene data; do not regenerate terrain at runtime or restore obsolete polygon editing as the native-map authority.

## Entry points and ownership

- `features/world/data/{river_bay,qingling_town,well_1,well_2}.tscn` contain native layers, not just runtime generated cells.
- `Ground_TileMap`: native ground/road terrain paint. `Obstacles_TileMap`: water, forest, rock, building atlas brushes.
- `Walkable_Mask` and `SafeArea_Mask`: paint/erase logical domains.
- Every HABITAT config has exactly one `Spawn_<id>`, `Activity_<id>`, `Chase_<id>` linked by `region_id`. Config owns profile/templates/member rules; native mask owns shape.
- Hidden legacy WALKABLE/BLOCKER/SAFE/ROAD geometry is migration provenance, not a competing authority for native terrain. HABITAT resources retain legacy shape fields for compatibility, but linked masks override them.
- Shared native TileSets at `features/world/data/tiles/`; external generated PNG atlases at `art/terrain/native_tiles/`. Original art unchanged.
- Editor plugin creates/duplicates/deletes habitat config and all three masks as one Undo action; duplicated cells shift by (2,2), IDs change once. New-map clone remaps mask region IDs and copies TileSets independently.

## Coordinates and runtime

64×32 isometric tiles, DIAMOND_DOWN, logical cell 32, layer position (-32,0), identity scale/rotation. The native cell center (0,0) corresponds to logical (16,16). Reject incompatible transforms instead of silently distorting routes. Painting/erasing whole cells uses native collision polygons as geometric data; imported edge alternatives preserve pre-migration partial contours.

WorldTileCompiler merges full cells and boundary polygons into PolygonDomain contours/holes. Navigation remains WorldNavigationService in planar logical coordinates. Native projected TileMap physics/navigation are disabled intentionally: enabling them would mix screen diamond distances with simulation distances. Existing radius/capsule checks, D09 safe diagonals, interpolation, movement speed and battle ice-wall navigation remain unchanged.

Runtime takes immutable TileSet + packed `tile_map_data` snapshots, installs two presentation layers once, then retains existing props and landmarks. No per-frame terrain painting, no reward/save ownership in layers. Mask visibility is editor-only display; hiding a mask does not erase its gameplay region. F6 validates before isolated preview and hides authored layers to avoid rendering duplicate floors.

Ground/road Terrain supports all combinations of empty/ground/road neighbors using alternative tiles. Do not omit empty-neighbor edge variants: that removes the outermost floor row/column. Obstacle and mask tools use the Atlas brush, not unsupported six-way Terrain transitions. Current textures reuse existing art; terrain transitions are cell-shaped, not an art-complete blended coastline.

## Verification requirements

Editor build validation must read the current edited tab, not the dock's cached root. Do not invoke compile_definition on an edited script instance: Godot can retain a placeholder during reload/build even when the file now contains @tool. WorldAuthoringSnapshot mirrors exported/native author and TileMap data into fresh off-tree canonical tool instances, preserving unsaved changes. It must not reload/replace the edited script, save a scene, skip invalid-draft validation, or initialize AI/save state. Regression: tests/editor_placeholder_regression.gd covers real non-tool placeholder, stale tab cache, unsaved erase, invalid/corrected draft and all registered map parity; evidence artifacts/world/placeholder-build-results.json.

TILE-01: native saved layers on all four maps; complete floor counts 24576/1536/3072/3072.

TILE-02: old/new geometry parity, habitat bounds/area/holes, map IDs, profiles, portals/entries unchanged; no progress reset.

TILE-03: erase changes walkability/spawn; obstacle brush changes navigation geometry; native Terrain painting keeps neighboring floor cells.

TILE-04: holes and neighboring-cell unions preserve body-radius legality. Disconnected habitat masks and missing/duplicate links block preview. Invalid drafts can still be saved.

TILE-05: transformed/disabled layers rejected; scene owners and native painted save/reload preserved.

TILE-06: editor selection, paint-data Undo/Redo, habitat add/duplicate/delete verified through actual Editor APIs on an artifact sandbox. This is not a human mouse-brush acceptance test.

TILE-07: render all four maps, run non-headless MOVE and full existing RTS/control/skill/progression/HUD regressions. Damage/result/settlement contracts unchanged.

Evidence: `artifacts/world/native-tilemap-results.json`, `native-editor-isolated.log`, `native-render-clean.log`, `native-map-*.png`, `native-movement-render.log`, `native-full-final.log`, `results.json`. Old scenes: `artifacts/tilemap-migration-2026-10-10/original-scenes/`. Migration tools are one-shot provenance utilities, never boot hooks. Editor API verification uses `--headless --editor --script res://tests/editor_native_tile_smoke.gd` on a tagged artifact sandbox after startup tab restoration; it never saves an active formal scene.
