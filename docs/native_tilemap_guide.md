# 原生等角 TileMap 製圖指南

**D20更新**：日常操作以 [人本製圖指南](human_authoring_guide.md) 為準。TileMap 移入 Ground 分組；怪區預設原生 Polygon2D，旧遮罩只在 Tile Brush 模式生效。本文保留原生地表／Terrain 技術說明；下文涉及舊 Dock 的步驟已過期，不再使用。

四張現有地圖已改為 Godot 原生 **TileMapLayer**，不用再用舊外框工具畫地形。依 Godot 的 [TileMapLayer](https://docs.godotengine.org/en/stable/classes/class_tilemaplayer.html)／[TileSet](https://docs.godotengine.org/en/stable/classes/class_tileset.html) 機制保存與編輯。

## 開哪個檔

在 Godot FileSystem 雙擊下列場景，再切到 2D：

| 地區 | 場景 |
|---|---|
| 青嶺河灣大世界 | `features/world/data/river_bay.tscn` |
| 青嶺鎮城內 | `features/world/data/qingling_town.tscn` |
| 古井一層 | `features/world/data/well_1.tscn` |
| 古井二層 | `features/world/data/well_2.tscn` |

不是改 `world_catalog.gd` 的啟動 fallback，也不是執行遷移工具；日常只改場景／TileSet／配怪 Resource。

## 畫地形、障礙及區域

1. Scene 樹選 **Ground_TileMap**；底部打開 TileMap 面板。Atlas 可直接選地面格；**Terrains** 選「地面」或「道路」畫筆即可鋪路／擦回地面。Ctrl+Z／Ctrl+Shift+Z 撤銷／重做。
2. 選 **Obstacles_TileMap**，使用 **Atlas** 畫筆。Atlas 橫向六欄依序為地面、道路、水域、森林、岩石、城牆；障礙選第 3–6 欄。**Obstacles 層上所有已畫格都算障礙**，清除阻擋用橡皮，不要畫地面格代替清除。在 Ground 層畫水／岩石亦會阻擋；道路不會。
3. 選 **Walkable_Mask**，打開旁邊眼睛或按 Dock「原生筆刷：通行範圍」顯示。Atlas 選第一欄的完整菱形格（第 16 行）。畫上就是可通行，橡皮挖洞。若需擴大地圖，同時修改根節點 `definition.extent`、鋪地面、畫通行遮罩。
4. **SafeArea_Mask** 同樣畫／擦；玩家可进入，怪隊不能穿越。這不等於刪除地形。
5. 遮罩畫完可以關眼睛，**顯示／隱藏不改邏輯範圍**。不要關 Inspector 的 Enabled，也不要移動、縮放或旋轉 TileMapLayer；位置須保持 `(-32,0)`，64×32 等角格對应邏輯格 32。

Terrain 目前提供地面↔道路自動連接。森林／水／岩石／城牆用 Atlas，並保留現有程序式裝飾；並非已畫好所有海岸／建築美術過渡。若要換素材，在 `features/world/data/tiles/<map>_terrain.tres` 的 TileSet Atlas 編輯；所有同一 TileSet 的引用會共用修改。自製阻擋格需要 `visual_kind`、`blocked` custom data 與 Physics Layer 0 的完整菱形多邊形。這些碰撞形狀轉成平面導航資料，**不要啟用投影畫面的 TileMap 碰撞／導航**。

現有範圍邊緣有細裁切 Alternative tiles，為保留原路線而設。一般新筆刷選完整基礎格，不必手動重用裁切格。

## 配怪、畫怪區

1. 世界製圖 Dock 選怪區配置（如 river、farm、forest、mountain 或 cave_hunt）。按「本區獨立設定」，Inspector 展開 `habitat → profile`，修改人口、主被動、重生、戰場與 `templates[].members[]`。
2. Dock 選「出生遮罩／活動遮罩／追擊遮罩」，按 **原生筆刷：所選怪區遮罩**。亦可在 Scene 樹直接選 `Spawn_<id>`／`Activity_<id>`／`Chase_<id>`。每層 `region_id` 對應配置的 `stable_id`。
3. 用 Atlas 完整格畫範圍／橡皮挖洞；保持 **出生⊆活動⊆追擊**，單個怪區每種範圍須連通。要兩塊獨立出生地，新增另一個怪區，不能只隔空畫兩島。
4. 「新增怪區」會建立配置和三張預設遮罩；「複製選取」會複製三層、偏移兩格並分配新 ID；「刪除選取」一起刪除配置及其遮罩，皆可 Undo。地形／通行／安全按鈕會選取既有原生層，不再新增舊多邊形。
5. 配怪與技能檔仍是 `features/units/data/*.tres`／`features/skills/data/*.tres`。古井一層鬼衛模板用 elite，二層用 boss；詳見 artist_guide.md。已有正式怪隊不因改模板而重抽。

旧 HABITAT.shape 欄位只是兼容資料；原生遮罩才是生效範圍。隱藏的舊多邊形節點保留為遷移來源，不要改它們期待新地圖跟著變。

## 地城入口與試玩

有高度的建築、山體及入口改用獨立 Sprite；詳見 [地景／Hover指南](scenery_authoring.md)。TileMap 負責地表及阻擋遮罩，入口輪廓／名稱說明由 sprite 接入。

城內／地城都是上述原生場景。入口、到達點與地標繼續由 World Authoring Dock 配置；落點使用邏輯座標。選目的地 map／entry，設好往返入口。編輯區域不會自動新增樓層。

按 **驗證／定位第一個錯誤 → Ctrl+S → F6**。F6 使用隔離世界、不保存正式進度；錯誤遮罩／入口會阻止試玩但不阻止保存草稿。F5 則讀正式存檔，修改後應停止並重新執行。地圖圖集 atlas 插畫仍需另行對位／繪製，不會從筆刷自動重畫插畫。

原場景備份在 `artifacts/tilemap-migration-2026-10-10/original-scenes/`，正式角色／背包／怪隊存檔未重置。遷移器只作留檔，不要反覆執行。

## 測試與尚需試用

80 項原生專項檢查覆蓋四圖身份／範圍、筆刷／橡皮影響邏輯、連接不缺格、錯誤配置與保存重開；四圖有實際渲染截圖。編輯器 API 的選層、Undo／Redo 和怪區管理另有 20 項 tagged sandbox 測試。完整回歸及耗時見 `artifacts/world/results.json`／`native-tilemap-results.json`。

**人工鼠標筆刷、縮放／平移後的畫筆操作仍待你實際試用**；自動 Editor API 測試不冒充人工驗收。
