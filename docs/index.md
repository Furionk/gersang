# Gersang 文檔入口

公開 GitHub 版本：[可選素材、無音樂執行與村莊安裝](optional_assets.md)。

彩虹冒險／火龍神殿動作遭遇：[試玩、控制、原生資料與驗證](rainbow_action.md)，查檔 `-Topic rainbow_action`。

轉珠怪／轉珠世界：[試玩與編輯](puzzle_world.md)／[D42契約](../specs/puzzle_world.md)，查檔 `-Topic puzzle`。

魔法學校・霍格愛茲地城／三階段血月首領：[遊玩與原生編輯](hogwarts_guide.md)／[D41契約](../specs/hogwarts.md)，查檔`-Topic hogwarts`。

資源分類、空白工具目錄與AI精準檢索：[現行政策](architecture/resource_policy.md)／[2026-10-13審視](audits/2026-10-13_resource_structure.md)。

SpriteSheet轉向／出招／腳底集中修正及千年鳥／鐵炮手／銅人補畫：[逐圖報告](audits/sprite_motion_2026-10-13.md)、[D40](../specs/sprite_motion.md)、[生成提示與版本](audits/sprite_motion_image_prompts.md)。

**現行製作入口：[兵種／技能／頭像／SpriteSheet／怪區／入口／地形指南](content_authoring_guide.md)。** 以D38十人預置＋D39可變動作幀為準；下方舊七人與永久招募記錄不是現行操作。

Malfory女魔法師／Crucio／Avada Kedavra／追加招募清單：[使用與調整](malfory_guide.md)／[D37契約](../specs/malfory.md)。

千年湖新怪／中央兩階段王及湖衣姬強化：[編輯指南](millennium_ecology_guide.md)。敵軍全滅後可操作收尾：[D36](../specs/victory_cleanup.md)。

湖衣姬新版形象：[美術契約與資源入口](../specs/kohime_art.md)，查檔`-Topic kohime_art`。

倉庫單獨存取及戰鬥特效：[操作指南](new_units_guide.md)／[D32歷史契約](../specs/roster_effects_polish.md)，查檔`-Topic roster_effects`。現行出戰上限10人由D38取代舊七人；全場火龍、大型魔爪尖刺及新火焰／雷擊素材保留。

新兵種／技能／怪物：[F2倉庫與試兵指南](new_units_guide.md)／[D31歷史招募契約](../specs/mercenary_storage.md)，查檔`-Topic mercenary_storage`；永久招募已由D38取消，完整角色存取／交換保留。新內容製作優先查D39。

兵種語音：[試音／製作指南](unit_voices.md)／[事件契約](../specs/unit_voices.md)。查檔用 `project_context.ps1 -Topic voices`。

**戰鬥地圖編輯入口**：[原生戰場 Artist 指南](battlefield_artist_guide.md)／[場景契約](../specs/battlefield_scenes.md)。五張正式戰場位於 `features/battle/maps/*.tscn`，原生 Ground／Walkable／Blockers／Scenery／五個 SpawnZones；查檔 `-Topic battlefields`。

河灣大世界豐富化：[效果與自行編輯](river_enrichment.md)／[D22契約](../specs/river_enrichment.md)。Scene/Scenery/RiverComposition有六類分區，使用新森林／山谷／濕地素材，不改怪區／入口／導航。

**目前製圖入口**：[人本原生工作流](human_authoring_guide.md)／[D20契約](../specs/human_authoring.md)：六圖原生分組、扁平配怪、2D 拖放、原生頂點，不再使用舊「世界製圖」Dock。

中國寺院地城：[少林寺素材／實際圍牆／護院示範](shaolin_temple.md)，原生地圖 `features/world/data/shaolin_temple.tscn`。

玩家地圖：[世界／地城投影全貌與定位](../specs/world_map_ui.md)。M 開圖，滾輪縮放、右鍵拖曳；地形及出入口直接取原生場景。查檔用 `project_context.ps1 -Topic map_ui`。

建築、山體、入口輪廓及跟隨游標提示：[Sprite 地景指南](scenery_authoring.md)／[D19契約](../specs/scenery_interaction.md)，查檔用 `-Topic scenery`。

新增地城：[千年湖素材／入口／單怪示範](millennium_lake.md)，原生地圖 `features/world/data/millennium_lake.tscn`。

製圖最新入口：[原生等角 TileMap 指南](native_tilemap_guide.md)／[D18契約](../specs/native_tilemap.md)。查檔用 `project_context.ps1 -Query tilemap`；地形、障礙與怪區遮罩已保存於四張現有 `.tscn`。

這裡是分類索引，不是另一份遊戲規格。本輪依使用者決定只Audit＋索引，**沒有搬動既有文件**。

AI開始：根目錄 `AGENTS.md` → `tools/project_context.ps1 -Query '<主題>'` →最多三份READ_FIRST →權威資料／指定程式方法 →相關測試。不要先全文讀README、來源長文、所有日誌或整個GameDirector。

```powershell
./tools/project_context.ps1 -List
./tools/project_context.ps1 -Query '兵種'
./tools/project_context.ps1 -Query '地震術' -Json
./tools/project_context.ps1 -Topic world
./tools/project_context.ps1 -Topic plugins
./tools/project_context.ps1 -Verify
```

| 要做什麼 | 現行入口 | Topic |
|---|---|---|
| 看架構／本次Audit | [架構與權威](architecture/project_map.md)、[Audit](audits/2026-10-09_structure.md) | architecture |
| 控兵、F1、技能確認／自動 | [最新操作](combat_controls.md)、[契約](../specs/combat_controls.md) | controls |
| 保護移動／鏡頭 | [契約](../specs/movement_feel.md)、[驗證](movement_validation.md) | movement |
| 戰鬥HUD／胜利2＋3秒及快回 | [契約](../specs/battle_presentation.md)、[驗證](battle_presentation_validation.md) | battle / ui |
| 兵種、敵人、召喚 | [兵種資料](design/units.md) | units / monsters |
| 技能／公式 | [技能插件](tools/editor_plugins.md)、[現行操作](combat_controls.md) | skills |
| 經驗／配點／派生數值 | [角色指南](character_sheet_guide.md)、[兵種資料](design/units.md) | progression |
| 物品／裝備／食品 | [物品契約](../specs/items.md)、[後台指南](items_debug_guide.md) | items |
| 世界、城鎮、地城／圖對位 | [世界內容](design/world.md)、[製圖](artist_guide.md) | world |
| 遭遇／戰力／導航／保存 | [規格入口](../specs/index.md)、[世界驗證](world_validation.md) | encounter / power / navigation / save |
| UI／立繪／縮放 | [角色指南](character_sheet_guide.md)、[契約](../specs/character_sheet.md) | ui |
| 插件／製作工具／預覽 | [插件與工具](tools/editor_plugins.md) | plugins / authoring |
| 美術與生成記錄 | 下方三份JSON；runtime仍看Resource/scene的素材路徑 | art |

本輪箭魂敏捷強化、S頁「重新配點」、進戰向下及非均勻怪物圖集：[D14契約](../specs/party_polish.md)、[驗證及畫面](party_polish_validation.md)，由skills／progression／art入口查閱。

## 文檔分類與優先序

最新使用者要求 → `specs/decisions.md` →現行topic契約 →原生 `.tres/.tscn` 資料 →現行指南 →來源／歷史。原始來源若與新決策相衝突，依新決策，不能覆寫來源冒充原文。

十人預置編隊／倉庫／Web 展示版：見 [D38](../specs/demo_web.md)，驗證證據在 `artifacts/demo-web-2026-10-11/`。

- **開發政策**：`AGENTS.md`；**導航**：本頁、`specs/index.md`、`specs/context_map.json`。
- **現行契約**：`specs/combat_controls.md`、`movement_feel.md`、`character_sheet.md`、`items.md`及decisions。
- **來源不可改**：`specs/sources/world_encounter_2026-10-08.md`；`items52.json`是來源事實，不是運行數值後台。
- **製作來源**：`art_manifest.json`、`v2_art_manifest.json`、`world_hud_art_manifest.json`，不當作runtime路徑權威。
- **歷史／部分失效操作**：`combat_v2.md`、`validation.md`、`v2_validation.md`、README下方舊操作。不要用其按住／Ctrl連射、舊四欄／疊窗或舊冷卻回退現版。
- **驗證報告**：`*_validation.md`是當次記錄，需看對應JSON、引擎及內容差異；報告舊不等於目前已驗。
- **生成證據**：`artifacts/`；根／tests的129個舊log、截圖、結果及sidecar已可逆歸檔到history/2026-10-13，新輸出放artifacts/tests。它們不參與預設AI檢索；測試程式和approved fixture仍在tests。

每份現有文檔的角色分類在 `specs/context_map.json`，`-Inventory`列出，`-Verify`檢查分類覆蓋、路徑及主題連接。
