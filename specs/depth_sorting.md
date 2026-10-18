# Automated foot-depth ordering — D29 (2026-10-11)

User approved fixed ground + native foot Y-sort + explicit foreground. Asset
presets plus per-instance override; natural occlusion, no fade/x-ray effects.

## Ownership and invariants

- ScenerySorting is presentation-only. Never mutate actor logic/positions,
  Walkable/Blockers, portals, spawns, IDs, rewards or save state for ordering.
- Ground remains existing negative tile bands. GROUND decor=-3200, DEPTH=0,
  FOREGROUND=1000. Existing ordinary skill VFX=3500; physical ice-wall segments
  use DEPTH without changing collision/navigation/timing.
- Actors, summons, world monster representatives and solid scenery use the same
  Z=0 and native Y-sort. No Y→z_index conversion/clamping per frame.
- Organizational ancestors Y-sort together, objects themselves are atomic:
  animation shake, image height, bars and internal artwork never change foot depth.
  Do not place interleaving scenery in separate CanvasLayers.
- Native Sprite origin is the contact/sort point. Offset compensates image
  placement. Calibration shifts position by basis*delta and offset by -delta in
  one undo action; image pixels stay unchanged under scale, rotation/mirror.

## Data / precedence

- WorldSceneryDefinition.sorting_mode int: GROUND0/DEPTH1/FOREGROUND2, default1.
  sorting_review_required + sorting_note are nonblocking artist guidance.
- Sprite/visual-author metadata scenery_sort_override: absent=inherited, 0–2
  override; scenery_sort_preset optionally selects a shared native Resource.
- Otherwise existing external WorldSceneryDefinition is used. Old embedded
  appearance copies use exact texture path + crop shared preset matching; an
  explicitly nondefault/review-marked embedded classification remains respected.
  Unknown PNGs default DEPTH, never guessed by filename/height.
- The preset index cold-loads once, not in actor/frame hot paths; editor resource
  save invalidates it. Resource fields remain runtime immutable.
- World snapshot/compiler carries resolved modes to GroundMap; native battlefield,
  editor preview and map atlas use the same policy. Sorting state is not a save
  version/content revision or a reason to reroll monsters.

## Editor / author safety

No Dock or input interception. Chinese Inspector category/override controls and
Resource picker use native undo. Selected foot cross is draw-only. Resource edits,
tree/selection/property changes refresh editor ordering, not every-object processes.

Reusable sorted_gate_parts.tscn demonstrates original PNG Region pieces with
independent near/far foot points and an explicitly overhead cap. Its visual-only
scenery_parts group may move/rotate/mirror/scale. Logical author/TileMap/polygon
nodes inside that group are rejected; regular calibration rules remain intact.
Per-instance part IDs are assigned in editor with editable children; source prefab
is not modified. No mass automatic PNG segmentation.

## Content and evidence

Original11 scenes +129 presets backed up in artifacts/depth-sorting-2026-10-11/before.
Classification is append-only,18 reviewed flat presets and69 mixed atlas presets
marked for review. classification.json records every reason and before/after hash.
No original scene bytes/images are changed by classification; runtime/editor
ordering is applied from Resource presets. One-shot classify_scenery_sorting.gd
refuses rerun/overwriting existing classification.

Run depth_sorting_suite headless + rendered, --sorting-editor-smoke sandbox,
non-headless world/movement_regression and unified --all. See
docs/depth_sorting_validation.md for actual results, historical draft failures and
unverified physical-mouse acceptance. Never weaken geometry checks to pass them.
