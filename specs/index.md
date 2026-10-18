# 遊戲開發檢索與契約入口

內容製作基礎：[D39](content_authoring.md)／[深入淺出指南](../docs/content_authoring_guide.md)。

最新：[D38 十人展示版與無 BGM Web](demo_web.md)，初始資料為 `features/progression/data/demo_setup.tres`。

Malfory／原生追加招募目錄：[D37](malfory.md)／[調整入口](../docs/malfory_guide.md)。

最新：湖衣姬 [D34](kohime_strength.md)、千年湖 [D35](millennium_ecology.md)、勝利可操作收尾 [D36](victory_cleanup.md)，[編輯指南](../docs/millennium_ecology_guide.md)。

## 優先序

使用者最新決策 → `decisions.md` → `sources/world_encounter_2026-10-08.md` → 既有功能規格。來源 SHA256：`67FF7A813F874197F993637AE3B901A6FED2E455DD7455BD67DF60D8220FF6FD`。

## 迭代入口

湖衣姬藍膚黑金甲冑／新版八方向Sprite及畫像見 [kohime_art.md](kohime_art.md)，Topic kohime_art。

倉庫單獨存取／火徑／雷擊／全場火龍／大型魔爪見 [roster_effects_polish.md](roster_effects_polish.md)，Topic roster_effects；D32覆蓋D31固定七人限制，主角固定、Active1–7。

湖衣姬／忍者／鐵炮手／新怪／F2試兵讀 [new_units.md](new_units.md) 與 [使用指南](../docs/new_units_guide.md)，Topic new_units。正式招募／換兵查 [mercenary_storage.md](mercenary_storage.md)，Topic mercenary_storage；D31 候補倉庫保存原兵進度，J/K立即、C導雷。

圖層／Z／遮擋／腳底排序讀 [depth_sorting.md](depth_sorting.md) 與 [Artist指南](../docs/depth_sorting_guide.md)，Topic sorting。D29统一世界／戰鬥原生Y-sort，素材分類與單件覆蓋；不是改通行或每幀Y轉Z。

快捷鍵修改／中文欄位說明／兵種資料分類／單Sprite／倒數世界更新讀 [editor_workflow.md](editor_workflow.md) 與 [快速指南](../docs/editor_workflow_guide.md)，Topic editor_workflow。D28取代D24一次抽籤，保留正式戰鬥凍結及4批60人。

怪物分佈／少林寺12隊／孔洞怪域／舊存檔搬位讀 [monster_layout.md](monster_layout.md) 與 [怪區指南](../docs/monster_layout.md)。D23取代D22的舊怪域保留，場景仍是權威。

火圈5秒／附近增援／多隊結算／戰場分批出生見 [multi_party_encounters.md](multi_party_encounters.md) 與 [調整指南](../docs/multi_party_encounters.md)，Topic encounter。D24取代單批／3秒，保留所有既有成員ID與原子結算。

背景音樂／BGM 切換見 [background_music.md](background_music.md)：六首指定本地 MP3、獨立 Music bus、1.2 秒交叉淡化；同曲不重播，載入不中斷，音樂不屬於可清除的戰場節點。

河灣地景／新增素材／填圖讀 [river_enrichment.md](river_enrichment.md) 與 [編輯／實測指南](../docs/river_enrichment.md)，Topic scenery。原生場景是擺放權威，一次性填圖工具不可重跑覆寫人工內容。

**目前製圖工作流 D20**：[human_authoring.md](human_authoring.md)／[簡明指南](../docs/human_authoring_guide.md)。用 `-Topic authoring`。沒有世界製圖 Dock；六圖原生分組、canvas 作者位置、扁平 Inspector、怪區 Polygon2D 頂點為預設；D18 地表／導航保留，舊怪域筆刷僅顯式兼容。

Sprite 建築／山體與入口 hover 讀 [scenery_interaction.md](scenery_interaction.md)，用 `-Topic scenery`。它補充 D18，不替換平面導航與原生通行遮罩。

原生等角地圖改造讀 [native_tilemap.md](native_tilemap.md)，用 `-Topic authoring`／`-Query tilemap`／`-Feature native_tiles`；四張 `.tscn` 的保存圖層是地形／怪區形狀權威。日常製圖見 [筆刷指南](../docs/native_tilemap_guide.md)，不再使用舊外框工具改這四張地圖。

先用 `tools/project_context.ps1 -List`／`-Query '兵種'`／`-Query '地震術'`／`-Topic world`取得有限packet；[文檔分類入口](../docs/index.md)與[架構](../docs/architecture/project_map.md)分清現行／歷史、原生資料／review匯出。`context_map.json`是查閱路由，`manifest.json`仍管需求／依賴／驗證；本輪不搬任何既有文件。

執行 `./tools/spec_context.ps1 -Feature encounter`（或 world / power / navigation / authoring / save / battle）。輸出相關讀取範圍與雜湊差異，不要求每輪重讀專案。`manifest.json` 記錄工作包、依賴、測試及狀態；狀態以實測報告為準。

移動／導航／鏡頭／角色呈現先用 `-Feature movement` 並讀 `movement_feel.md`。這是使用者要求保護的契約，不得按早期來源規格恢復四向階梯移動。

物品／裝備／消耗品／Debug讀 `-Feature items` 和 `items.md`；原生 `.tres` 是運行時權威，來源JSON和匯出CSV不是另一套自動覆寫資料。

角色立繪／行囊／技能說明／Shift配點讀 `-Feature character` 和 `character_sheet.md`；同一角色畫面互斥能力與裝備模式，不恢復獨立立繪疊窗。公式試算共用執行數據，不能創建另一套技能傷害。

戰鬥輸入／F1／冷卻／目標確認／自動補給讀 `-Feature controls` 和 `combat_controls.md`（D11）；取代早期按住／Ctrl連射及自身技按鍵直接施放，不得隨其他修正恢復。

箭魂敏捷加成／重配點／進戰朝向／山豬石衛圖集讀 `-Feature party_polish` 和 `party_polish.md`（D14）；Topic skills／progression／art有對應入口，禁止改共享召喚藍圖或回退平均八排裁切。

經典戰鬥HUD／胜利2＋3秒及快速回圖讀 `-Feature battle_presentation` 或 `-Topic battle`，見battle_presentation.md（D16）。暴雷I即放／靜態等角圓爆破見combat_controls.md的D17／NOVA；不能用旧「所有SELF都需左擊」斷言回退最新決策。

UNCHANGED_VALIDATED 指同一版本已做相關自動／匯入檢查，不代表所有 GUI 閘門通過。地圖幾何以 `features/world/data/*.tscn` 的作者節點為準；調整內容時另檢查該場景及相關 Resources，而不是只讀 runtime 腳本。

## 契約

- PartyBuilder: immutable definition → independent resolved members, stable IDs.
- PowerCalculator: unit/party rating, one summary for UI and battle.
- WorldNavigationService: legal domains, connected components, full non-partial paths.
- WorldContext: world data, clock, allocator, RNG streams and injected services; preview is isolated.
- EncounterService: synchronous reservation, countdown/cancel, token-checked callbacks.
- BattleBridge: snapshots in, outcome/member results out; no trusted rewards from UI.
- SettlementService: one candidate and receipt per encounter, persist then publish.
- MapDirector: recreate presentation from retained data, not respawn the world.
- SaveService: primitive-only full snapshots, atomic replacement, revision/recovery validation.

## 完成規則

Phase 0–6 依依賴前進。測試替身不算正式戰鬥；headless 不算實際 GUI 操作。每個工作包保留已跑的命令、結果、引擎、內容雜湊及未完成項目。工具產生的 `artifacts/world/` 不可冒充手動驗收。
