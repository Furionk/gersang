# 世界與地城投影地圖 UI — 2026-10-10

使用者要求依巨商式呈現，直接投影實際世界／地城全貌，玩家及出入口準確定位。這取代玩家地圖原本的 cartography-v1 圖片與 192×144 地城障礙示意；美術原圖及作者工具 atlas 底圖保留。

## 資料與呈現

- 原生場景編譯出的 WorldMapDefinition 是地圖資料權威。WorldMapProjection 使用同一 GroundMap.build_exploration 路徑安裝原生 TileMapLayer 和 WorldSceneryView，保留圖層偏移、TileSet、圖格、sprite 腳底與排序。所有地區均支援，不在 UI 硬編寫地形。
- 一份獨立 World2D 場景由圓形小地圖和展開地圖兩個 SubViewport 共用。每個 viewport 以自己的 canvas_transform 直接渲染場景，縮放不放大一張預製全圖。相機或地區不變時保留渲染結果，地區切換只重建一次靜態呈現。
- UI 不建立角色、怪隊、導航、碰撞或遭遇。定義 Resource 不可變，來源場景、存檔、移動與戰鬥機制不變。
- Iso.project 是唯一地圖投影。地形、玩家、地標、出入口和到達点共用同一比例與中心；反向點選使用 Iso.unproject。全貌保持等角比例並留黑邊，避免拉伸。
- 全圖範圍包住地區 extent 及景物完整 sprite，外加邊距。小地圖以玩家權威位置為中心。

## 操作

- M 開啟／關閉目前地區全貌；重新打開或換圖回到全貌。
- 滾輪以游標位置縮放；右鍵拖曳；全貌按鈕重置；我的位置按鈕標示玩家。
- 青色菱形為出入口、綠色白環為玩家、金點為地標、淺綠點為到達位置。標籤在 UI 畫出並避開彼此；到達點常態只畫點，選取才顯示名稱。
- 右側清單使用當前地區的 portals、landmarks、entries；portal 名稱取已作者化入口 sprite，目的地由 map_definitions 查出。地點按鈕與圖上標記回傳原生邏輯座標，圈選位置並在側欄顯示。
- 點圖只定位，不走路、不瞬移、不進入口。地圖空白邊界點擊不提交位置。地圖是既有模態視窗；关閉釋放模態，原有角色／背包流程保留。
- 面板、側欄及底部控制隨視窗縮放；地圖打開時隱藏覆蓋標題的物品 Debug 按鈕，F2 功能與平常入口保留。

## 驗證

tests/map_projection_suite.tscn 使用隔離世界與保存，涵蓋河灣、城鎮、古井兩層、千年湖；每區檢查原生層與景物、投影／反投影／相機座標、動態清單、engine 注入的滑鼠點擊與滾輪、拖曳邏輯、底部按鈕、模態關閉與重開，以及 800×450、1920×1080、900×900 排版。

2026-10-10：headless 193 passed / 0 failed；實際圖形渲染 198 passed / 0 failed。run_all --all 原有 118 個頂層檢查全部通過（含 16 個既有 suite 及移動場景）；非 headless movement_regression 40 passed / 0 failed，包含 30／120 FPS。原先 world_hud_suite 的「圖片 atlas 對位」檢查改為實際場景投影，其他既有斷言保留。

證據：artifacts/world/map-projection-{headless,render}-results.json、map-projection-{headless,render}.log、map-ui-full.log、map-ui-movement-render.log、projected-map-*.png、projected-minimap-well_2.png。原修改檔备份位於 artifacts/map-ui-2026-10-10/original。

圖形測試是引擎視窗與注入輸入的自動驗證，並已檢視截圖；不是人工滑鼠試玩或原生編輯器筆刷驗收。D09 移動保護和既有未驗證人工門檻不變。
