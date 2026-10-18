# Multi-party encounters and combat maps — D24

User decision 2026-10-10: flame rings on hero/enemies, 5→4→3→2→1, random
nearby reinforcement, at most four batches / sixty enemies, improve every arena.

## Contracts

- EncounterRules: countdown_ms=5000; max_enemy_parties=4;
  reinforcement_radius=320; reinforcement_chance=.35. Inspector editable.
- D28: during COUNTDOWN eligible ACTIVE same-map parties inside the radius are
  tested every1s in stable ID order with persistent `encounter` RNG. Species
  approach chance overrides habitat defaults. No changes to composition RNG.
- Complete CHASE-domain paths include body radius, safe-zone and obstacle checks.
  No path means no roll/no reservation. No cross-map/floor/river/wall teleport.
- Approach candidates reserve synchronously and walk to legal offsets near hero.
  On arrival within48 (configurable), unobstructed segment and final capacity,
  species/habitat join chance is rolled; failed arrival may retry after1s.
  ! does not guarantee admission. Up to8 provisional approaches, at most4 final
  batches/60 actual enemies. Deadline releases all non-admitted candidates.
- COUNTDOWN continues normal AI/spawns; battle freezes world as user confirmed.
- Primary party selects the arena. Other nearby party types may reinforce it.
- enemy_id is retained for old saves; enemy_ids and approaching_ids enumerate all
  owned parties. Old snapshots lacking these lists remain one-party encounters.
- Final snapshot is checkpointed before dispatch. Failure releases every party.
  Cancel, recovery, retreat, defeat and guarded return release all reservations.
- SettlementService commits all participants/slots/rewards in one candidate.
  Victory requires every participating enemy dead; XP sums all actual members.
  Retry uses the same candidate and duplicate results never award again.
  Existing one-loot-per-encounter policy is unchanged. Nonparticipants untouched.
- Presentation-only fire crown follows existing visual poses; number above hero
  and compact top status panel do not own clocks, locks or movement.

## Combat map authority

Native scenes in features/battle/maps own current layouts (battlefield_scenes.md).
The following legacy fallback fields are not artist-scene authority:
EncounterDefinition exports battlefield_cells (44×38), battlefield_obstacles,
enemy_spawn_centers (four sectors). Defaults enlarge the prior34×28 playable
area by1.76×; native TileMapLayer has1672 tiles with seeded organic material
variation and two crossing lanes. Broad themed islands leave connected routes.
GroundMap creates matching logical obstacle collision/navigation and retains
dynamic ice-wall counters and flight maps. Existing biomes/temple/lake sprites
form boundaries and interior landmarks; no source art is deleted or replaced.

RTS uses every snapshot batch, persistent member IDs, full release stats, HP/MP.
Each batch is positioned around a different authored spawn center; safe spawning
retains the existing navigable-cell guard. Player initial deployment/facing and
D09/D11/D12/D14/D17 controls remain unchanged. World geometries are not rewritten.

## Evidence and boundaries

- tests/multi_party_suite.tscn: probability boundaries, paths, late parties,
  cancel/recovery, fixed IDs, aggregate settlement/save retry, real multi-party
  RTS/retreat/return and four reachable sectors on all five arenas.
- Non-headless captures and JSON: artifacts/multi-party-2026-10-10/.
- Existing sealed-choke ice-wall regression now explicitly authors its historical
  obstacle fixture; it must still demonstrate blocked retention, close retaliation
  and resumed movement at wall expiry. Do not weaken those assertions.
- Test_runner unreachable check uses a real current obstacle, not a stale coordinate.
- Full regression plus non-headless MOVE40 required. Captures are real rendering,
  not proof of manual mouse playthrough or final hand-authored art approval.
