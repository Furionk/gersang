# 戰場原生 Scene 製作

在 Godot FileSystem 打開 `features/battle/maps/`：

| Scene | 戰場 |
|---|---|
| meadow.tscn | 草原 |
| mountain.tscn | 山道 |
| cave.tscn | 古井洞窟（兩層共用；可另做新場景） |
| shaolin_temple.tscn | 少林寺 |
| millennium_lake.tscn | 千年湖 |

這些是正式戰鬥讀取的場景，不是大世界同名場景。不能以修改大世界 `features/world/data/*.tscn` 代替。

## 原生操作

- `Terrain/Ground`：用 Godot TileMap 畫筆鋪地板、道路及變化；TileSet 可加自己的80×40菱形素材。現有四格調色盤為地表、暗地表、亮地表、道路。
- `Terrain/Walkable`：畫可走範圍，擦掉格子會變成不可走的孔洞。選中才顯示半透明綠色；沒有選中時不蓋住建築。
- `Terrain/Blockers`：畫阻擋格，優先於 Walkable。選中顯示紅色；圖片本身不會自動阻路。
- `Scenery/Prop_*/Artwork`：原生 Sprite2D，可移動、旋轉、縮放、換圖片、複製或刪除；可自行新增 Sprite／場景實例。腳底 pivot 影響 Y-sort，障礙另畫在 Blockers。
- `SpawnZones/Position_1…5`：直接拖 Marker。圈顯示邏輯半徑的等角範圍，Inspector 可改 Radius、Capacity、Allowed Teams（Both／Allies／Enemies）。保持 Marker 比例1，用 Radius 改圈大小。
- 根 `Battlefield Cells`：戰場邏輯格數，新增格需同時鋪 Ground／Walkable；根與 Terrain 圖層保持原點校準，圖層位置(-40,0)、80×40等角格。不要移動 TileMap 圖層代替畫格。Godot Diamond Down 的格中心自帶(40,20)，這個原點將它校準到平面碰撞的投影中心。

## 出生及試玩

若你已開著舊原點的場景且有未保存刷格，先保留這些修改，將 Terrain 下三層的 Position 都設為(-40,0)再保存；不要直接重載丟失修改。沒有未保存修改才可直接重開場景。紅色Blocker是物理障礙；現有導航另外留一格安全邊距，兵種也有自身碰撞半徑，正常不會把腳底中心貼到紅格邊緣。

預設5個主位置，每次由戰鬥seed隨機分配1批我方＋最多4批敵方，不重複主位置、單位不重疊。同一seed可重現；一隊會排在圈內可行格，不一定站在Marker精確中心。現有系統仍只一批我方，未新增友軍增援。

每個初始圈容量60，若縮小或填障礙，請同步調低 Capacity；容量應至少覆蓋可能入場的整批人數。各圈須互通，不能用障礙把敵人完全隔離。無效配置會列出節點路徑及原因，不瞬移、不吞掉世界怪隊。

保存後 **F6** 隔離試玩目前戰場，或 **F5** 經原有世界遭遇進入。F6 不載入／修改正式進度。使用 Godot 原生 Undo／Redo，沒有新增製圖 Tab。場景只有初次遷移時建立，遊戲不重生成、不覆寫你的刷格或擺放。

新增戰場：複製一張到此目錄，設定根 Arena Id；在 ArenaDefinition 的 Encounter → Battlefield Scene 指向新場景，再將怪區 Battlefields 配到對應 Arena Id。既有戰場 `.tres` 仍負責戰場註冊及配怪關係，場景負責美術與布局。

契約：[battlefield_scenes](../specs/battlefield_scenes.md)。測試結果與截圖見 `artifacts/battlefield-scenes-2026-10-11/`。原生編輯器 API 驗證不冒充人工滑鼠畫筆驗收。
