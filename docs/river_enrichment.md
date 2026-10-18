# 河灣大世界：山林、河岸與生活區

已實際改動 `features/world/data/river_bay.tscn`，不只是概念圖。使用新增森林／花崗岩／濕地／枯林模組，搭配竹叢、紅楓、井、市集、糧車、陶甕及圍欄。

## 看成果

- [改後全貌](../artifacts/river-enrichment-2026-10-10/after-overview.png)
- [森林](../artifacts/river-enrichment-2026-10-10/after-forest.png)
- [河岸與木橋](../artifacts/river-enrichment-2026-10-10/after-river.png)
- [入口生活区](../artifacts/river-enrichment-2026-10-10/after-town.png)
- [山道](../artifacts/river-enrichment-2026-10-10/after-mountain.png)

原174件地景 → 新建958件、21件不合河道的舊自動山石存档 → 現可見1111件。保留道路、入口及怪區中央的點擊／狩獵空地，不把整幅畫面封滿。河岸用既有河道阻擋範圍接水面，橋搭在原本可通行缺口，沒有改成可走水域。

## 你自己繼續改

在 Godot 打開 river_bay.tscn：

| Scene 樹 | 用途 |
|---|---|
| Scenery/RiverComposition/Riverbanks | 蘆葦、岸石與木橋 |
| Woodlands | 竹叢、混合樹冠與林緣 |
| Highlands | 邊界山脊、既有岩石阻擋、山地地被 |
| VillageLife | 市集、井、車、甕、爐和房舍 |
| FieldEdges | 紅楓與田邊植物 |
| GroundCover | 低矮蕨草、碎石和過渡小景 |

仍使用原生 2D 拖動／Ctrl+D／Delete；各組 Y-sort 与保存的 Artwork 支援遮擋。新素材定義在 `features/world/data/scenery/river_biomes/`；不要改原始 atlas 的共享內容來調一件物件，改資源或 Make Unique。

Ground/Ground_TileMap → 底部 TileMap → Tiles：選來源「河灣地色」，五排苔土、落葉、土徑、碎石、耕地。原來源的 Terrains 地面／道路仍可用。河道來源在 Obstacles_TileMap，保留原碰撞；**改水的可走範圍要另外編輯遮罩**，這輪並沒有動它。

日常只改場景／Resources。**不要重跑一次性 enrich/refine 工具覆寫你的手工擺放。** 移動巨石／山體到新地方時，圖像不會自動生成新阻擋；仍依 [原生製圖指南](human_authoring_guide.md) 在 TileMap 設占地。

## 實測狀態

Godot 4.7.1 Compatibility。河灣專項21項通過，確認24576地表格、完整導航輪廓、入口／怪區、原生owner、Y-sort、留白與保存重開。接入新專項後統一回歸 **110 passed／0 failed**（197383ms）；原生Editor API 28項通過；非headless MOVE 40項通過；文檔路由21項通過，最終匯入無腳本／shader錯誤。資料見 artifacts/river-enrichment-2026-10-10/{results.json,all-final.log,editor.log,movement-render.log,import-final.log}。

已實測重跑 --finalize 被拒絕；地圖與兩張導出貼圖 SHA256 前後相同，guard.log 是預期的保護拒絕，非遊戲錯誤。refine 在任何寫入前檢查是否已完成，防止再次改暗貼圖或覆蓋人工擺放。

渲染與benchmark是真實GPU輸出：NVIDIA RTX PRO 6000 Blackwell Workstation Edition，Windows，三個固定視角各120幀；AI／hover已停，只作render負載參考，不是低階機或12對60戰鬥FPS保證。中位幀間隔約16.67ms；draw calls中位為482／240／328（入口／林地／橋頭）。同次記錄有既有battle_hud_layout anchors warning，未為本轮地景修改無關HUD。完整數字見 [benchmark.json](../artifacts/river-enrichment-2026-10-10/benchmark.json)。

引入貼圖時曾碰到 TileMapPattern alternative 預設-1產生缺格；已明確寫0並加完整格數／valid TileData 回歸。TileSet source 必須先挂入TileSet才可寫custom data；舊失敗log保留，最終clean log與實際渲染不再有地景／shader錯誤。

## 視覺評閱 — Taste Receptor Atlas v2

來源是上述實際render，先短邊512 WebP比對，再檢查1800×1000局部。只評環境（無HUD／角色／狀態圖示）；TYPE、ICON、AFF及相關UI項為N/A，工具聯絡表檔名不是遊戲字體。這不是素材IP權利審核；參照巨商構圖，沒有抽取客戶端圖片。

| 適用 receptor | 0–2分 | 可見依據 |
|---|---:|---|
| COMP-LEAD-ENV | 2 | 土路與橋帶向入口，明確避開大片叢林 |
| COMP-VALUE-GROUP | 1 | 大區域可辨，局部土紋仍有重複感 |
| COMP-FOCAL-SINGLE | 1 | 全貌有多個地區；局部入口為主焦点 |
| COMP-DEPTH-LAYERS | 2 | 山／樹冠／路面高度層次明確 |
| COMP-NEG-SPACE | 2 | 四怪域中心與主路保留空地 |
| COMP-BALANCE | 2 | 林地重、城門／田野輕，山脊收邊 |
| COMP-FRAME-ENV | 2 | 山林形成路口與練功空地框景 |
| COMP-SCAN-PATH | 2 | 河岸、路、村落形成可追蹤順序 |
| COMP-HORIZ-LEVEL | 2 | 固定等角投影，不混用俯視透視 |
| COMP-SAFE-EDGE | 2 | 全貌地圖邊界完整，不截斷主要入口 |
| LIGHT-MOTIV | 1 | 大致左上光，舊／新素材仍有软硬差別 |
| LIGHT-KEY-FILL | 2 | 岩面、樹冠、土面均可辨 |
| LIGHT-RIM-OWN | 2 | 沒有用统一霓虹rim掩盖轮廓 |
| LIGHT-SPEC-LOT | 2 | 無随機高光物件搶焦点 |
| LIGHT-POST-STACK | 2 | 無额外bloom／DOF／色差堆叠 |
| COLOR-LAYERS | 2 | 森林／水／土路／岩面以值域區分 |
| COLOR-COUNT | 2 | 土綠灰藍主色，紅楓少量點綴 |
| ORIG-REF | 2 | 改造既有世界而非貼参考圖做背景 |
| ORIG-STRUCT | 1 | 大部分脚底貼地，組合模組仍有局部底墊感 |
| ORIG-TILE | 1 | 原生格完整，但土紋repeat仍可見 |
| ORIG-SET | 1 | 新叢林與舊山石的細節密度略不同 |
| ORIG-READ | 2 | 桥、路、山、林在縮圖仍清晰 |
| ORIG-VALUE | 1 | 部分綠色植物內部值域過近 |
| ID-RENDER | 1 | 同為預渲染等角風格，旧／新素材粗细未完全統一 |
| ID-LIGHT | 1 | 大致一致，仍可精修局部光感 |
| ID-DRIFT | 2 | 四個局部維持同一地面／植物色系 |

COMP 18/20、LIGHT 9/10、COLOR 4/4、ORIG 8/12、ID 4/6；**43/52（83%），B**。無適用硬閘門0分；仍有1分项，不宣称100%還原。後續優先：ORIG-TILE土紋變體與边缘过渡、ORIG-SET/ID-RENDER舊山石统一、COMP-FOCAL-SINGLE入口局部手工构图。人工遊玩／鼠標製圖驗收仍待你試用。
