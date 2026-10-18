# 河灣／少林寺怪物分佈

原生場景：`features/world/data/river_bay.tscn`、`shaolin_temple.tscn`。
展開 `MonsterAreas`，選怪區，用原生Polygon2D頂點調整：

- SpawnArea：出生範圍。
- RoamingArea：日常遊走範圍。
- PursuitArea：追擊及返巢外域。
- VisualExclusion 子多邊形：孔洞；勿把被排除的山體／樹林填回活動區。

Inspector展開怪區的 SpawnProfile 修改人口、模板、等級及行為。
少林寺現有前庭4隊、中庭5隊、後庭3隊；合共12隊，而非原來一個單體。
河灣保持22隊。地面導航／地形／入口與玩家進度不被重置。

旧存档保留成员及ID，必要时移动到合法出生点；少林寺缺少的新槽补位。
修改本轮布局后不要用旧工具重生成覆盖艺术家的场景。行为／增援设置另见
`docs/multi_party_encounters.md`。

验收：`res://tests/monster_layout_suite.tscn`（75项）；图像／报告：
`artifacts/monster-layout-2026-10-10`。截图为真实引擎捕获，非人工鼠标验收。
