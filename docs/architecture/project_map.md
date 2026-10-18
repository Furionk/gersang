# 專案架構與資料權威

Godot 4.7.1，Typed GDScript、2:1呈現；專案根有 `project.godot`，不是舊Unity AREA_PM2。這頁是維護地圖，不複製數值設定。

## 現有結構與責任

| 位置 | 責任／權威 |
|---|---|
| `common/data/` | 共用Resource schema：Unit、Skill、Item、Feel、Stats、Experience等 |
| `features/units/` | 單位／Vitals／FSM；`data/*.tres`是兵種數值與技能配置，`art/`是專用sprite |
| `features/skills/` | 施法資格與持續效果；`data/*.tres`是技能，`art/`是特效 |
| `features/battle/` | 選兵／命令／轉場協調、F1守衛；不擁有永久獎勵 |
| `features/world/` | `definitions/`資料schema、`runtime/`時鐘／RNG／遭遇／保存、`authoring/`作者節點、`data/`地圖scene／戰場Resource |
| `features/progression/` | 每角色經驗／配點／裝備，戰鬥數值算法；`data/`係數／物品／經驗曲線 |
| `features/ui/`, `presentation/`, `audio/` | 呈現及聲音，讀狀態／下指令，不擁有結算 |
| `features/settings/` | 操作設定與InputMap；GameSettings Autoload |
| `addons/<plugin_id>/` | 原生Editor插件；作者類型可在features中被scene使用，不因此搬到addons |
| `art/` | 跨世界／戰鬥共用地形、UI、美術；角色／技能專用圖集留在各feature |
| `specs/` | 契約／決策／來源／驗證雜湊及AI路由索引 |
| `docs/` | 操作、設計導航、製作指南、Audit及當次驗證說明 |
| `tests/` | 固定入口及隔離測試；不要搬到features以免破壞 `res://tests/`隔離前綴 |
| `tools/` | CLI查閱／資料製作工具；區分只讀與寫入，不能為找資料執行builder |
| `artifacts/` | 生成證據／review匯出，已有.gdignore，預設不檢索 |

## 所有權與查閱順序

1. 兵種／物品／技能永續定義以原生Resource為準；角色HP/MP、冷卻、自動施法在每個執行物件，不改共有.tres。
2. 地圖作者節點以 `.tscn`為準，WorldCatalog保留bootstrap/fallback；不要改fallback卻期待既有scene地形更新。
3. WorldSession持有WorldContext，世界怪隊及出生槽跨卸載保留。世界Clock／戰鬥Clock分離。
4. GameDirector接入真實RTS，SettlementService提交一次性獎勵／世界快照；不是戰場直接重複發獎。
5. Autoload順序：GameSettings → PartyProgress → WorldSession。實際設定在 `project.godot`。
6. 正式保存用 `user://`，不在專案文件夾。測試的路徑隔離是安全契約，不只是美觀分層。

## 有限讀取

`tools/project_context.ps1` 依registry現有topic輸出最多3份READ_FIRST、資料权威、程式方法、有限檔案雜湊及證據；用-List取得即時數量，不在文案寫死18。自然語言多義時列候選，不替你擴大讀所有模組。`-Expand`只在接口變更／失敗／缺資料時使用。來源／生成物分類另見[資源政策](resource_policy.md)，用`tools/project_inventory.ps1 -Json`只讀盤點。

`specs/context_map.json`只管檢索與文檔角色；`specs/manifest.json`仍管需求／依賴／驗證狀態。兩者不是遊戲設定；不复制HP／傷害／地標坐標到JSON索引。舊 `spec_context.ps1 -Feature`保留作驗證相容入口。

## 目標文檔擺放（未搬）

```text
AGENTS.md / README.md           短入口，不持續堆歷史操作
specs/contracts/<topic>.md      現行契約（將來遷移需更新鏈接）
specs/sources/                  不可改原始來源
specs/decisions.md              決策優先序
docs/index.md                  人／AI入口
docs/architecture/             模組與資料權威
docs/design/                   兵種／技能／世界設計意圖及資料入口
docs/guides/                   操作與藝術製作指南
docs/tools/                    插件、工具、寫入風險
docs/validation/                指向原始證據的當次報告
docs/history/                   明確失效的舊操作文案
docs/audits/                    日期化稽核快照
artifacts/<領域>/               生成日志／圖／JSON／CSV，不是規格
tests/<feature>/                未來新測試可按feature加子資料夾，保留tests前綴
```

這次只有新索引文件採上述位置，既有文件與所有運行資產沒有搬動。未來新功能維持feature-based，不造全域scripts/sprites雜袋。搬移清單與風險見 [Audit](../audits/2026-10-09_structure.md)。

參考：[Godot專案組織](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)、[res://與user://](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)。以上是本案的具體適配，不冒充引擎要求唯一結構。
