# Visual-aligned monster distribution — D23

2026-10-10 user request: align monster movement/distribution to current visible
world; increase Shaolin population. Supersedes D22's old habitat preservation.

- River stays22 parties: river6 / forest6 / farm6 / mountain4. Native spawn,
  activity and chase polygons now follow legal connected32-unit cells avoiding
  visible tree/building/mountain footprints, navigation blockers, portals and safe
  areas. Mountain has an interior exclusion hole; no terrain/scenery/portal moves.
- Shaolin12 parties: front_patrol4 (Lv6–8,2–3members,passive), bronze_guardian5
  (Lv8–10,2–4members,active), rear_patrol3 (Lv10–12,3–4members,active).
  Existing guardian resource/art only. Native three-domain regions follow courts.
- All domain containment validates filled sets with holes, not merely outer rings.
- WorldPopulationLayout revision2 reconciles supported older map snapshots:
  preserve original member arrays/IDs/progress/receipts/cooldown deadlines; legal
  deterministic relocation only where required; add missing slots, spawn only
  new empty slots. No reroll of existing composition and no reward side effects.
- Migration is idempotent, deferred during active encounters and checkpointed
  before normal boot publication; failed saves remain protected/paused.
- One-shot authoring/fixture tools are provenance only. Native scene data is the
  runtime authority; do not rerun tools over subsequent artist edits or silently
  regenerate approved_monster_layouts.json to hide a regression.
- Evidence: tests/monster_layout_suite.tscn75 checks; actual rendered maps in
  artifacts/monster-layout-2026-10-10; unified runner also includes the suite.
