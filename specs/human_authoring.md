# D20：以創作人為中心的原生製圖

## 決策與範圍

使用者要求大幅改善工作流。以 Godot 原生 Scene tree、2D 移動、TileMap、Polygon2D、Inspector、Undo/Redo 為日常介面；取消常駐 World Authoring Dock 及其自製鼠標工具。Terrain、障礙、通行、安全仍以保存 TileMapLayer 為權威。怪區新增原生 Polygon2D 形狀模式，覆蓋 D18「所有怪區必須三層遮罩」的預設，但保留顯式 Tile Brush 兼容模式。

## 場景結構

```
WorldMap2D
  Ground         native terrain / obstacles / walkable / safe
  Scenery        independently selectable sprite objects
  Entrances      portals / arrival points
  MonsterRegions WorldMonsterRegion + SpawnArea / RoamingArea / PursuitArea
  MapLabels      landmarks / legacy road data
  Technical      archived legacy nodes and region masks
```

所有分類父層保持 identity transform；作者節點只允許平移。新／遷移作者 position 為 Godot canvas 等角顯示座標，WorldAuthorTree.logical_position 編譯時 unproject；執行時一律沿用平面距離、導航、速度及 D09 插值。舊場景預設 LEGACY_LOGICAL，因此備份仍能直接編譯。保存 authored order 避免列表重排改變來源順序。

WorldMonsterRegion 的常用設定扁平化；複雜混合隊伍不重寫為单怪。compile_habitat 深複製再覆蓋參數，不修改原始 Resource。Polygon2D 頂點／洞按完整父 transform 轉平面。形狀來源只可一種：Polygon 不受舊 mask 覆寫；Tile Brush 才讀對應兼容遮罩；未連接遮罩的 brush 模式拒絕試玩。

舊作者 ID、map ID、portal routes、arrivals、party member rules、數值、地面幾何均保留。新建／複製作者取得獨立 ID，Undo/Redo 重掛同一實例時不重生 ID。Build／驗證仍使用 detached WorldAuthoringSnapshot；遞迴鏡像所有分類／原生 shape，不呼叫編輯器 placeholder 方法，不重載場景代替未保存資料。

Sprite2D Artwork 保存 scene owner、group selection 與 foot anchor；沒有用偏移 preview 冒充原生移動軸。只選取的作者／範圍顯示編輯標記。EditorPlugin 不攔截畫筆／Polygon／pan／zoom 輸入。Inspector 局部提示、中文常用欄位與目的地下拉繼承原生 Theme；少量 Project → Tools 操作不建立另一個常駐 editor。

## 驗收

可加性人口同步：已初始化的世界地圖也必須依 canonical `<map>/<habitat>/<index>` 補 missing slots，不限地圖／不需 revision bump。只對本輪新槽生成，不修改舊槽的計時、pending party、成員、ID 或人口；不刪 surplus slots。遭遇／转場／paused 延後，安全回圖再次 ensure_map，經完整 checkpoint 保存；失敗保留同一份記憶體配置並暫停。新增怪區無合法格時保留 EMPTY/pending 配置，由正常 spawn_due 重試。測試 additive_population_suite 含實際存檔唯讀副本與真遊戲 WorldPartyView。

外觀作者變換：CANVAS 座標且有 sprite_definition 的 SCENERY／LANDMARK／PORTAL 可平移、旋轉、非零縮放及鏡像。compiled.scenery.artwork_basis 傳遞父節點 basis，GroundMap 只套於 Sprite，不改 foot position、觸發半徑、Walkable／blockers。共享 Resource 不可修改。零比例／非有限值仍拒絕。插件 build 失敗必須顯示具體驗證原因；不以通用 callback failed 作唯一回饋。scenery_transform_suite 驗證千年湖原生1.575倍、旋轉、非均勻比例、鏡像與幾何不變。

通用編輯契約：所有地圖／未來新增入口共用同一規則，不設 shaolin_exit 特例。原生地圖由 WALKABLE 遮罩定義可行面，GROUND 的 blocked tile 與 OBSTACLES 定義扣除障礙；Sprite／SCENERY 不是碰撞來源。移動普通建築父節點不改通行幾何，移動 PORTAL 父節點只更新外觀及互動點，接近其可達觸發範圍。NPC 另受怪區／安全區限制。TileMap 圖層原點校準、無效多邊形、落點及路由有效性檢查仍保留；不能為允許移動外觀而取消這些資料檢查。portal_approach_suite 比較拖動前後通行／障礙幾何完全一致。

入口拖動：可直接拖動入口父節點（例如 Scenery/shaolin_exit），保留原生 Undo/Redo 與作者 ID。選中入口顯示等角觸發範圍；點入口由 WorldContext.approach_portal 尋找範圍內可達落腳點，不要求中心可站立、不修改障礙或瞬移。完全沒有落腳點仍拒絕並提示檢查通行／障礙。Artwork 子層只調外觀，不能代替入口邏輯位置。測試：portal_approach_suite。

編輯器層級保護：WorldTileLayer 的 WALKABLE／SAFE／SPAWN／CHASE 是邏輯遮罩，預設隱藏；僅選中時顯示半透明彩色 overlay，離開選取即隱藏。不可使用不透明的地表貼圖覆蓋建築，也不可藉此修改 tile cells、導航、建築位置或 Y-sort。真編輯器沙盒測試旗標 `--mask-layer-smoke`，證據 `artifacts/editor-layering-2026-10-10/`。

D20a：使用者確認 town_door 新位置。tests/world/approved_portal_edits.json 明列唯一位置差異，由 test-only approved_content_changes 對不可變備份產生比較副本；不得覆寫備份、從目前地圖自動學習期望值或跳過其他欄位比較。自行配圖之後的新變更仍需另行確認／更新測試資料。

- HU-01 六圖分組、native sprite owners、無未選取藍點。
- HU-02 前後完整平面地形、怪域 outer/holes、ID／路由／兵種數值一致。
- HU-03 原生拖動、頂點修改、孔洞、單怪／混合隊伍、不改共享 Resource。
- HU-04 Inspector／Tiles／Polygon Undo/Redo、template add/duplicate/delete、新 ID 保持與保存重開。
- HU-05 真 placeholder、unsaved edit、invalid/corrected draft、current-tab build。
- HU-06 全戰鬥、冰牆、技能、養成、物品、HUD、世界圖與 MOVE 30/120 FPS 回歸；非 headless movement。
- HU-07 人工滑鼠畫筆、縮放／平移後拖頂點及 FileSystem 拖範本獨立列 unverified，Editor API 不冒充人工驗收。

相關檔案由 context Topic authoring 提供；結果见 docs/human_authoring_validation.md。遷移工具僅一次性、先驗證後保存；不在啟動時重生成作者內容。正式進度不清空、不強制重抽既有怪隊。
