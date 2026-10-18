# 世界製圖與試玩指南

**目前請從 [人本原生製圖指南](human_authoring_guide.md) 開始。** 下文早期 Dock／巢狀配怪步骤是歷史，D20 已改成原生 Scene 分組、中文扁平 Inspector 與 Polygon2D。不要照舊流程重建或覆寫地圖。

## 2026-10-10：第一次自行改圖／配怪

先停掉正在執行的遊戲，以免你看的仍是舊Resource。四張地圖已遷移為原生 TileMapLayer；優先閱讀 [原生等角製圖指南](native_tilemap_guide.md)。Editor API 的 Undo／Redo 已有隔離測試，人工滑鼠筆刷驗收仍待試用。

1. 在Godot開啟本專案；Project Settings → Plugins確認 **World Authoring** 已啟用。FileSystem開 `features/world/data/river_bay.tscn`（大世界）、`qingling_town.tscn`（城內）、`well_1.tscn`／`well_2.tscn`（古井一／二層）。不要改舊Unity專案。
2. 改地形：Scene 樹選 Ground_TileMap，底部 TileMap 原生 Atlas／Terrains 畫筆鋪地面／道路；Obstacles_TileMap 用 Atlas 畫水域、森林、岩石、城牆。Walkable_Mask／SafeArea_Mask 畫通行及安全範圍。舊外框／孔洞幾何不再是這四張地圖的權威。
3. 改配怪：Dock選怪區配置，按「本區獨立設定」，Inspector展開 habitat → profile。出生／活動／追擊改在 Spawn_<id>／Activity_<id>／Chase_<id> 原生遮罩畫筆編輯；保持出生⊆活動⊆追擊。
4. 展開 `profile.templates[0] → members[0]` 選 `definition` 兵種Resource、數量與等級。模板可有多條MemberRule混合不同怪物；`representative`只是大地圖代表sprite，不是多加一隻成員。
5. 連接地城：新增「入口」和目的地的「到達點」，在Dock選目的地map／entry，按「套用入口目的地」。一、二層都是獨立場景，需要各自保存；返回入口也要配置。落點放在可通行地面、且不要落在入口觸發區內。
6. 按「驗證／定位第一個錯誤」→ Ctrl+S →「開始隔離預覽」看怪隊遊走及倒數 → **F6**試該地區和真正RTS。預覽／F6不保存正式進度。

| 要改什麼 | Inspector字段 | 單位／含義 |
|---|---|---|
| 地區怪隊人口 | profile.target_party_count | 隊，不是單隻怪物 |
| 死後重生 | respawn_min_ms / respawn_max_ms | 毫秒；30000即30秒 |
| 主動追人 | profile.rules.active | true主動／false被動 |
| 發現玩家／拉入戰鬥 | rules.aggro_radius / engage_radius | 邏輯world units，不是畫面像素 |
| 每隊哪種怪及幾隻 | templates[].members[].definition / min_count / max_count | 引用features/units/data/*.tres |
| 每名怪物等級 | members[].min_level / max_level | 1–100 |
| 戰場候選池 | profile.arena_pool | meadow／mountain／cave；不是地城map_id |
| 模板抽選比例 | profile.weights | 與templates項數一致；空陣列沿用等權 |

例如古井一層：選 `cave_hunt` 怪區，人口設6；MemberRule選 `elite.tres`、每隊2–4名、Lv.15–25；重生設30000–45000；arena_pool為 `["cave"]`。這些只是教學例子，不是目前預設值；本次遷移保留現有配怪。

**看到舊怪隊的原因**：F5載入的是正式完整世界存檔，已有隊伍的ID／成員／等級快照不會因改模板而重抽。先用F6／隔離預覽看新配置；大改幾何後，舊存檔位置也可能不再合法。不要為了看新怪直接刪除正式存檔或任意改content_revision。若需要另開正式世界，先備份world_state.dat及其.bak／.tmp，再另行決定遷移或重置。

既有怪區／入口的stable_id及已登記地區map_id應保留。新增地區用「從目前場景複製成新地區」產生新ID，而不是把舊ID改掉。

### 怪物數值／技能要改哪個檔

怪物定義在 `features/units/data/`：`beast.tres`山豬／山野妖獸、`archer.tres`山寨弓兵、`elite.tres`黑甲石衛、`boss.tres`赤魂獄使。古井一層的「古井鬼衛」怪隊用elite，二層同名怪隊用boss；畫面隊名與成員兵種名是兩件事。

在Godot Inspector改max_health／max_mana／damage、attack_range／attack_interval、speed、armor、defense、accuracy／evasion、magic_resistance、strength／agility／intelligence／luck及experience_reward；實際戰鬥還會套等級／屬性派生規則，不是只讀一個damage常數。

`skills`陣列引用 `features/skills/data/*.tres`。公式、MP、目標、範圍、效果在技能Resource；`ai_enabled=true`才由怪物AI考慮，並要有足夠MP。目前敵方技能AI主要為自身範圍技，不能承諾任意友軍／方向技都能自動選好目標。

`common/data/catalog.gd → ENEMY_PATHS`只是試驗戰場四種敵人的名單；正式地圖按怪區MemberRule.definition配怪。`common/data/unit_definition.gd`是Inspector字段schema，不是集中怪物數值表。新增世界怪物可新增獨立UnitDefinition .tres，再在模板選取；不要改schema預設值當作修改某一隻怪。

## 開啟

Godot 4.7.1 開啟此專案。F5 是正式遊戲；若遊戲已開著，先停止再重新執行，世界登錄在啟動時載入。

`features/world/data/river_bay.tscn`、`qingling_town.tscn`、`well_1.tscn`、`well_2.tscn` 是可編輯的地圖場景。開啟其中一張並按 F6，可啟動**不保存正式進度**的真實戰鬥試玩。怪隊在區域中遊走；左鍵點怪接近後倒數三秒。被動倒數 Esc 可取消。

外域 6144×4096；城內 1536×1024；地城每層 2048×1536。人物比例不因地圖放大而放大。

## 原生工具

本節由 [原生等角 TileMap 製圖指南](native_tilemap_guide.md) 取代。地形、障礙、通行、安全及怪區形狀使用 TileMapLayer；入口、到達點、地標及配怪仍使用 World Authoring Dock／Inspector。插件新增／複製／刪除怪區會同步處理三種遮罩，Undo／Redo 同一組提交。

保留 D09：平面半徑幾何、capsule直線及安全斜向尋路；原生投影 TileMap 碰撞／導航不能打開。隱藏遮罩不影響邏輯，舊 polygon 欄位不是原生地圖的形狀來源。

## 城門、地城與新地區

新增 ARRIVAL 到達點，以「放置／移動落點」吸附格中心。新增 PORTAL，選目的地 map_id／entry_id，再「套用入口目的地」。到達點必须在合法通行面、位於目的地入口觸發區之外。

示例路線：青嶺河灣 → 青嶺鎮；青嶺河灣 → 古井一層 → 二層 → 一層。進入口步行觸發，轉場保護需走出觸發區後才可再次使用。

從目前模板建立新地區：輸入新的 ID，按「從目前場景複製成新地區」。工具不覆寫同名檔案，重新配置幾何、入口、地標及怪區後保存。新場景位於 features/world/data，遊戲啟動時自動登錄；不需改 GDScript。要從舊地區抵達新地區，仍要配置並保存雙向入口。

根節點 definition 設定地區名稱、extent、grid_size、terrain、安全返回地圖及落點。幾何、怪區與入口以場景中的作者節點為準，不修改 definition 裏保留的舊幾何副本。

## 世界繪圖對位

玩家的大地圖與圓形小地圖現在直接投影原生地形及景物，城內／地城顯示目前區域或樓層全貌。玩家、出入口、地標與到達点共用實際場景座標；操作與驗證見 [投影地圖 UI](../specs/world_map_ui.md)。新增或修改地圖後重新啟動，即以編譯後的原生場景資料顯示，不需另畫玩家地圖圖片。

作者工具仍可顯示半透明原創 atlas 底圖，用於描摹地標與道路。definition.atlas_projection_origin / scale 是作者底圖的對位參數，正值比例不可為零；玩家投影地圖不再使用這組 atlas UV。

目前只開放示例區域，不是整張圖所有國家均可遊玩；也未聲稱每條繪製海岸與岩石已像素級重建。

## 預覽與驗證

「開始隔離預覽」使用獨立時鐘、IDs、RNG 與記憶體存檔替身。紅點怪隊、綠點玩家；選取工具左鍵點地面移動或點紅點接戰。此預覽驗證遊走、倒數及快照；真正 RTS 請用 F6。停止後丟棄全部預覽狀態。

「驗證」顯示配置錯誤，能對應 ID 的錯誤會選取相關節點。錯誤阻止工具預覽；仍可保存草稿。檢查外框／孔洞、三區包含、IDs、模板、入口落點、戰場配置。

## 戰力及保存

UnitDefinition → 世界配置評分：base_power + level_power_growth × (level−1) + 裝備 power_bonus；全隊只加總上陣單位。傷害仍使用既有戰鬥屬性與技能公式，兩者分離。

正式完整保存為 user://world_state.dat（含備份／暫存恢復），原 party_progress.dat 是保留的遷移來源。測試均使用隔離資料。結算保存失敗時在結果視窗重試，未成功前不領獎或回圖。未知內容／存檔版本不覆寫。

## 尚需人工驗收

另一位操作者使用 GUI 完成：外框＋孔洞、拖點撤銷、複製／刪除、保存重開、入口連接、預覽停止與換 seed、從模板新增完整地區。這些不是 headless 通過就算完成的項目。
