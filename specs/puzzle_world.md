# D42 — 轉珠怪與轉珠世界

Approved2026-10-14. Godot-only local integration; no Web release.

## Lifecycle and ownership

River Bay adds four stable habitats `puzzle_fire/water/grass/electric`, ten parties
each, one to three Lv25 monsters. World speed255, battle speed360, respawn15–25s.
Existing native geometry, safe zones,5s countdown, four batches/60 enemies and
additive population synchronization remain authoritative. Never replace old habitats
or reroll old members. Defer additions while encounter-locked.

First basic attack acquires director `puzzle` mode synchronously and causes no ordinary
damage. All living puzzle monsters enter together. Preserve the original battlefield;
freeze units, selection, effects, projectiles, summons and timers. Entry and return
each have0.4s fade out and0.4s fade in; battle music continues.

PuzzleBoard owns cells/RNG; PuzzleCombat owns temporary combat arithmetic;
PuzzleController owns input/turn sequencing; PuzzleView only submits commands and
renders. PuzzleBattle owns transitions and commits HP through UnitVitals damage/heal
methods, preserving MP and death/XP signals. Puzzle enemies dead returns to RTS;
other enemies must still die. Allied roster extinction defeats even with living summons.
SettlementService alone awards rewards; D36 cleanup and SAVE_BLOCKED retry remain.
No mid-puzzle save schema: interruption recovers the existing pre-battle checkpoint.

## Board and combat

6×5, equally weighted fire/water/grass/electric/heart. Initial board has no automatic
matches and at least one adjacent matching move. First swap starts6s; press without
swap costs nothing. Release/timeout resolves, including zero-combo turns. Fast drag
traverses every adjacent cell; diagonal skips resolve horizontal then vertical.
Focus loss pauses puzzle clocks. Horizontal/vertical3+ runs qualify; connected same-color
qualifying cells form one combo. Separate groups count separately. Gravity/refill and
skyfall repeat until stable. Stable boards without an adjacent match are shuffled.

Each group multiplier is `1+.25*(count-3)`. Sum same-color multipliers, multiply by
`1+.25*(total_combos-1)` and affinity. Every living matching soldier attacks once in
roster order using entry resolved attack. Chosen target persists while alive, otherwise
next living enemy; one hit never spills. Fire→grass→water→fire is2×, reverse .5×;
electric/other cases1×. No ordinary RTS affinity changes.

All deployed main/mercenaries participate, never reserves/summons. Total HP/maxHP are
sums of actual members. Damage/healing distribute by living maximumHP, redistributing
cap overflow; hearts never revive. Each three-heart group restores10% entry team
maximumHP with the same extra-orb/combo multipliers. User update2026-10-14: enemies
use independent real-time cooldowns (initial6–9 seconds, reset7.5 seconds), including
idle, dragging, cascades and voiced player actions. Focus loss and transition freeze
these clocks. Dead enemies cannot retaliate; newly dead allies skip queued attacks.
Lethal enemy damage immediately ends input and resolves defeat. Enemy attacks
deal8% entry team maximumHP. Monster HP is16×Lv25 gunner resolved attack, currently550.4.
Defaults are editable in `features/puzzle/data/default_rules.tres`.

## Native definitions and presentation

`UnitDefinition.puzzle_element`: fire0/water1/grass2/electric3, default water.
`puzzle_monster: PuzzleRules`: null for ordinary soldiers, non-null for this species.
Fire: gunner/teppo. Water: merchant/guard/kohime. Grass: healer/supplier/malfory.
Electric: mage/controller/ninja. Save definition IDs/revisions remain unchanged.

Wide windows keep a centered portrait combat area and extended background. Full
deployed roster fits two portrait rows. Original pearl PNG/layout is shared and tinted;
orb symbols are original vector UI. F6 on puzzle_battle.tscn runs a temporary preview
model without modifying party data. One-shot author scripts are provenance only.

## Validation

Run `python tools/run_puzzle_checks.py puzzle_world_suite`, then repeat with `--render`.
Also run persistence/population/multi-party/victory/full/MOVE regressions. Evidence
lives in `artifacts/puzzle-world`. Physical-input fixture `tests/puzzle_playthrough.tscn`
uses one60HP target, no reinforcements and an authored swap board; it is not production
balance proof. Keep legacy full-suite failures visible; do not weaken art/navigation checks.

## 神抄之塔 extension — 2026-10-14

User requested a new dungeon of variable-level, variable-size elemental packs and several very strong rapid-attack kings. Native shenchao_tower scene adds16 habitats/28 parties, tiers30–39 /50–59 /70–79 and four Lv90 kings with two guards each. Dedicated arena retains the original authored temple collision/deployment layout with independent celestial artwork without editing its source. River adds tower_door/tower_return only. Retain existing terrain and original routes. Counts, cooldowns and design are listed in docs/puzzle_world.md.

PuzzleRules.monster_health(actual_level) uses resolved monster level; river monsters retain their actual level when balance revisions refresh stats. PuzzleBattle copies each enemy's rule reference and level into its runtime snapshot; PuzzleCombat copies scalar cooldown/damage values from that enemy rather than the triggering enemy. Resources remain immutable. Normal encounter/death/settlement remains authority. Run shenchao_tower_suite plus puzzle, entry persistence and rendered MOVE. Never rerun author_shenchao_tower over an authored scene.

## Continuous play update

Latest user request removes turn waits: stable board immediately reopens input; attacks/heals drain independently at0.06s spacing during ready/drag/cascade states. Match and fall animations last0.05/0.06s. Background voice queue deduplicates soldiers and cannot alter gameplay timers. Immediate defeat/victory cancels pending input/actions.

## Celestial challenge update — 2026-10-14

Canonical Resources now own river HP16x/cooldown7.5s, tower HP16/20/24/80x and cooldown8/7/6/2.5s. King initial delay2.5–3.5s and new death respawn20–30s; active saved respawn deadlines remain unchanged. Existing MonsterBalanceRefresh updates numeric stats by balance_revision with wounded ratios and identity preserved, deferred while paused or encounter-locked. No save schema change.

Native tower scenes own marble/gold platforms, cloud sea, elemental seals and an original celestial tower inspired by the supplied reference. Artwork cannot create navigation. Preserve world masks, portal coordinates, arena blocked cells and deployment zones exactly. Tower puzzle encounters choose the celestial background; normal river/F6 background remains unchanged. One-shot upgrade refuses to overwrite celestial_revision scenes. Run tower_challenge_suite and shenchao_tower_suite plus the standard puzzle/persistence/full/rendered MOVE gates.

## Hit feedback — 2026-10-15

PuzzleCombat snapshots combo count into queued attacks. PuzzleImpact is presentation-only: bounded48 records, deterministic serial variation, 0.10s flash/0.20s local shake/0.85s float labels, strength capped at10 combos. PuzzleView composites concurrent beams/rings/sparks and actual resolved damage; board/input rectangles do not move. No gameplay timer, hit-stop or damage multiplier changes. Focus pauses effects. Test concurrent input, source-combo retention and bounded cleanup.

## Dark horde and king expansion — 2026-10-15

Latest request supersedes former tower counts:48 parties /20 habitats. Four king habitats each3 parties; newly spawned groups contain2 Lv95 kings and4 guards. King HP multiple140, cooldown2s, damage14%, balance_revision2 retains old HP ratio. Four new passive dark_guard_* habitats before throne each3 parties of12–18 Lv99 dark units. Dark rules: HP multiple220, first4–8s, reset2s, damage1.2% per unit. Neutral affinity, existing five-orb board unchanged. Dark boolean in rules is presentation metadata; world tint and puzzle near-black tint agree. Preserve old occupied parties; counts/stronger composition fill only new or respawn slots. No map geometry or art regeneration.

## 2026-10-15 暗密空間（取代王座前黑暗怪群配置）

- 神抄之塔最深處新增 `abyss_door`，前往獨立原生地圖 `shenchao_abyss`（暗密空間），出口返回塔頂 `abyss_return`。原塔地形、四階王群、既有入口保持原樣。
- 黑暗群珠移至暗密空間：12 隊、每隊12–18隻Lv99；塔內現在36隊／16區，暗密空間13隊／5區。第13隊是唯一Lv100「轉珠之鬼」。
- 新原創PNG：黑洞星空、透明玻璃平台、轉珠之鬼，位於 `art/terrain/shenchao_abyss/`。來源、SHA256及生成提示保留於 `artifacts/secret-abyss/`。未修改生成原圖；場景以透明度調整玻璃。Boss為單張靜態Sprite，使用既有程序動作與受擊效果，沒有宣稱多方向逐格新動畫。
- 轉珠之鬼HP＝同級火銃手解析攻擊×1800，6秒準備後每1.6秒造成隊伍最大HP18%傷害，重生90–120秒。黑暗怪群數值保持原設定。數值集中在 `tower_ghost_rules.tres`；暗屬性沿用中性相剋，棋盤仍五色。
- `PuzzleRules.enemy_texture` 為可選原創敵圖，入場複製引用到戰鬥快照；世界、RTS與轉珠畫面顯示同一Boss。單體Boss放大顯示；攻擊演出不增加操作鎖。
- 舊存檔只移除塔內已退休的 `dark_guard_*` 隊伍與槽，其他隊伍、玩家進度和計時保持。遭遇鎖定或暫停時延後；退休定義保留供舊遭遇恢復。新地城首次造訪建立自己的穩定出生槽，不把原地城的敵人ID或半完成傷害帶入新圖。
- 可直接開啟 `features/world/data/shenchao_abyss.tscn` F6隔離試玩；實際路線為河灣→神抄之塔→塔頂暗密空間。新原生戰場 `features/battle/maps/shenchao_abyss.tscn`。一鍵作者腳本 `tools/author_shenchao_abyss.gd` 僅為一次性來源，不可重跑覆蓋美術。
