# 多隊遭遇／戰場調整

現在：主角及已參戰怪隊腳下火圈，頭上5→1；抽中增援會出現「!」並走近。
最多4批／60名，首隊决定戰場；未能在倒數內抵達的不入場。

## 想自行調數值

選地圖 `MonsterAreas` 下怪區 → Inspector 的 SpawnProfile → Rules：

- Countdown Ms：5000。
- Reinforcement Radius：320。
- Reinforcement Chance：0.35；每秒嘗試走近的機率，0不走近，1每次接受合法接近。
- Reinforcement Join Chance：0.65；抵達後的加入機率，感嘆號不保證參戰。
- Reinforcement Check Ms：1000；每秒重新判定，不是開場一次决定。
- Reinforcement Join Distance：48；仍需無牆阻隔，不能隔牆拉戰。
- Max Enemy Parties：4（含第一批）。

物種 Resource 在 `features/units/data/monsters/`，兩個 Reinforcement 機率
設 -1沿用怪區，0–1覆蓋。倒數世界繼續，真正戰鬥世界凍結。

敵方總數還受 ArenaDefinition.Enemy Capacity 限制，最多60。
場景儲存後重新執行；不會重抽既有怪队成员、覆寫正式進度。

現在戰場直接編輯 `features/battle/maps/*.tscn` 原生 Scene，
見 [Artist指南](battlefield_artist_guide.md)。以下只是沒有Scene時的舊fallback：

EncounterDefinition 的「戰場布局」：

- Battlefield Cells：格数，默认44×38；每格40平面单位。
- Battlefield Obstacles：Rect2i，逻辑格障碍；留空使用主题默认。
- Enemy Spawn Centers：四个平面坐标，每批一个中心。应置于可达空地。

草原／山道／古井：`features/world/data/meadow.tres`、`mountain.tres`、
`cave.tres`（由 Catalog.encounters 返回）。少林寺及千年湖：
`features/world/data/shaolin_temple_arena.tres`／`millennium_lake_arena.tres`
展开 Encounter。默认地图拼装在 `features/world/ground_map.gd`；地表是原生
TileMapLayer，装饰使用现有原生Scenery资源，不修改大地图场景。

## 检查／图片

运行 `res://tests/multi_party_suite.tscn`；加 `-- --capture` 产生实际渲染图。
查看 `artifacts/multi-party-2026-10-10/results.json` 与 `all-final.log`，
初次失败日志不是最终通过证据。截图为测试状态，不是手动操作验收。
五种战场都在同目录 `arena-*.png`；四批敌人示例 `four-batch-battle.png`。
