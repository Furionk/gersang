# Sprite scenery and entrance interaction — D19

The native ground TileMap must not flatten buildings, mountains or entrances. Their visual authority is authored WorldAuthorNode SCENERY/PORTAL/LANDMARK + WorldSceneryDefinition resources. SCENERY is enum value 8; old author enum values remain unchanged. Sprite placement does not change logical walkable/obstacle masks or portal permissions.

## Ownership and interfaces

- WorldSceneryDefinition: texture, atlas_region, foot_anchor, sprite_scale, tint, alpha_threshold, outline color/width, name/description. Existing props atlas is reused; original PNG unchanged. Gate crop removes neighboring pine fragment without cropping its main silhouette.
- WorldMap2D.compile_definition builds scenery records separately from existing portal route dictionaries. Root and author positions stay logical; the editor preview offsets sprite by Iso.project(position)-position. Generated editor children have no owner and cannot leak into saved scenes.
- GroundMap creates WorldSceneryView objects at projected foot positions under the existing Y-sorted render root. They have no projected physics/nav collider. Runtime definitions are shared/read-only; ordinary decor shares style materials, only a handful of portals have independent hover materials.
- WorldHoverController caches current ground's views, uses sprite-local CPU alpha BitMaps created once during loading, picks the highest foot-Y overlap and never loads textures during hovering. Transparent atlas padding is not interactive.
- The shader samples alpha within explicit atlas bounds, outlining the actual silhouette lime green. No rectangular hover frame. Vertex tint is multiplied exactly once. Sampler is passed to helper functions explicitly; headless success is not shader-compilation proof.
- WorldHoverOverlay is a nonblocking PanelContainer + VBox labels: dark translucent backdrop, centered gold title, white description, green approach hint. It follows cursor immediately, clamps/flips at viewport edges, uses independent UI font scale and shrinks after wrapping layout settles.
- World clicks go through GameDirector._unhandled_input, after GUI has consumed its events. A valid portal-sprite click calls WorldContext.move_player(real_portal_point), never direct teleport/settlement. Existing proximity, synchronous ownership, destination validity, save retry and transition callbacks remain authoritative.
- Hover is cleared on GUI overlap, modals, countdown/loading/battle/results, map unload and shutdown; restoring cursor shape does not change F1 confinement preference.

## Review and regression

SCENE-01 saved sprite objects and all pre-existing routes/arrivals unchanged (new unrelated routes may be added, never removed or rewritten).

SCENE-02 opaque/transparent hit tests, independent highlight, title/description, pointer follow and compact content height.

SCENE-03 actual left-click input approaches real portal; tooltip does not consume the click; GUI and character panels suppress world hover.

SCENE-04 countdown/map transitions clear hover and no freed-node callbacks survive. Check 800×450 and 1920×1080 edges.

SCENE-05 non-headless render captures four maps and counts actual lime silhouette pixels; scan engine logs for shader/resource errors, not only test exit status.

SCENE-06 full regressions and non-headless MOVE preserve D09/D18, combat and save ownership. New/deleted objects are visual only unless native masks are also authored.

Tests: `tests/world_scenery_suite.tscn`, unified `tests/run_all.gd -- --all`, `tests/world/movement_regression.tscn`. Evidence: `artifacts/world/scenery-headless-results.json`, `scenery-render-results.json`, `entrance-*.png`, `scenery-full-final.log`, `scenery-movement-render-final.log`. Physical mouse/editor hand acceptance remains unverified.

Original four scenes preserved in `artifacts/scenery-2026-10-10/original-scenes/`. The one-shot author_world_scenery tool is not a startup hook. Concurrent additional regions/assets must be preserved, not replaced with old snapshots to force a test green.
