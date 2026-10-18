# 三件事就能改世界：鋪地、放物件、配怪

圖層／人物被景物蓋住：用[D29排序指南](depth_sorting_guide.md)。素材預設＋單件「沿用／貼地／立體／前景」，Z自動管理；原生Inspector可以校準腳底並Undo，不改Walkable或入口位置。需要多腳底的大圖可用sorted_gate_parts範本，不批量亂切原圖。

2026-10-11更新：[編輯工作流指南](editor_workflow_guide.md)。純裝飾已改成單層 Sprite2D；在其原生 Texture／Region／Offset 改圖，腳底為移動軸。只有入口／地標邏輯仍保留 Artwork。下文舊 Sprite Definition 操作適用這些邏輯物件，不再是純裝飾的圖像權威。兵種資料改分 data/mercenaries、monsters、summons；共同 art 未搬。

新增怪區同步：保存地圖後重新執行，進入該圖時會依穩定 ID 自動補新增區域／新增人口的出生槽，不必提高 Content Version 或刪存檔。舊怪隊、成員、冷卻及玩家進度保留；戰鬥／轉場中延後到安全回圖再補。降低人口不會立即刪除既有怪隊，刪區／改 ID 不等於安全重命名。沒有合法出生格的槽會等待重試，不會瞬移出生。先用 F6 檢查範圍，再用正式遊戲驗證。

### 入口拖動（少林寺示例）

這是所有地圖的通用規則，不限少林寺：Walkable_Mask 決定哪裡能走，Obstacles_TileMap 和地表標成 blocked 的 tile 決定哪裡不能走。建築／山體 Sprite 只是外觀，拖其作者父節點不會自動改障礙；需要堵路時另外畫障礙格。怪物再受到自己的活動／追擊域及安全區限制。不要用拖動整個 Ground／TileMap 圖層代替畫格，這些層仍須保持格線校準。

選 `Scenery/shaolin_exit` 父節點，用原生 2D 移動工具拖動並保存，不必單獨移動 Artwork。選中時綠色等角圈表示觸發範圍；圈內只要仍有角色可到達的地面，遊戲點入口就會走到合法落腳點，不再強迫站在中心。整圈被障礙覆蓋／無法到達時仍會提示，不能跨牆或瞬移。拖建築不會自動重畫障礙 TileMap。

入口拖動回歸：portal_approach_suite 21/21；非 headless movement_regression 40/40（30/120 FPS）。證據 artifacts/editor-layering-2026-10-10/portal.log、movement-portal.log；未冒充人工滑鼠驗收。完整回歸仍有舊世界人口等測試失敗，不宣稱全專案通過。

這是目前的製圖入口（D20）。不再使用「世界製圖」Dock。在 Godot 開啟 `features/world/data/river_bay.tscn`，切到 **2D**；其餘五張城鎮／地城採同一流程。

## 1．鋪地形

Scene 樹展開 **Ground**：

| 選哪一層 | 用哪個原生工具 | 影響 |
|---|---|---|
| Ground_TileMap | 底部 TileMap → Terrains → 地面／道路 | 地表外觀 |
| Obstacles_TileMap | TileMap → Tiles 畫／擦 | 水域、山石等阻擋 |
| Walkable_Mask | TileMap → Tiles；必要時開眼睛顯示 | 玩家可走範圍 |
| SafeArea_Mask | TileMap → Tiles | 安全區，怪物不得進入 |

使用 Godot 原生畫筆、矩形、選取及圖樣；Ctrl+Z 撤銷，Ctrl+Shift+Z 重做。分類父節點保持原點／比例1，TileMap 本身保持 (-32,0)。圖片與阻擋是兩件事：放了一座山的圖片，仍要在 Obstacles_TileMap 畫出占地。

## 2．放建築、山體、入口

FileSystem 的 `features/world/authoring/templates/` 有三個可拖入 2D 的範本：

- `scenery.tscn`：建築／樹木／山體，放到 **Scenery**。
- `portal.tscn`：城鎮／地城入口，放到 **Entrances**。
- `monster_region.tscn`：怪區，放到 **MonsterRegions**。

也可使用 **Project → Tools → 地圖 → 新增…**，會放在目前畫面中央及正確分类。建築直接用原生移動工具拖；Ctrl+D 複製，Delete 刪除。圖片的腳底和原生移動軸現在在同一位置，不用「邏輯座標」落點工具。

選物件 → Sprite / Hover → Sprite Definition：選現有 `features/world/data/scenery/*.tres` 或自己的透明 PNG 定義。要改單件樣式，先 **Make Unique**／另存 Resource，避免改到其他同款。圖片預設縮放改 Sprite Scale，腳底改 Foot Anchor；單件建築／地標／入口可直接縮放或旋轉作者父節點，遊戲同步呈現，不影響導航遮罩。比例不能為零；邏輯範圍與 TileMap 格線層仍保留各自的校準限制。

入口 Inspector 有中文的 **目的地地圖／目的地落點**下拉。原生穩定 ID 自動生成；既有 ID 不應修改。目的地落點是另一个 ARRIVAL 节点：可在目的地 Entrances 複製现有到達点、拖到可走地面並改顯示名稱。新增落點須保存目的地後重新驗證，讓目錄讀到它；到達點不要放在任何入口觸發圈內。

## 3．放什麼怪、放幾隊

Scene 樹展開 **MonsterRegions**，選 river／farm／forest／mountain；Inspector 直接顯示：

- **怪物種類**：下拉選兵種；技能與基礎數值仍來自 `features/units/data/*.tres`。
- **每隊最少／最多隻數**、**最低／最高等級**。
- **怪隊總數**：例如6代表6隊，不是6隻。
- **重生最短／最長（秒）**：直接輸入秒，不用換算毫秒。
- **主動追擊玩家**：開啟為主動怪。
- **Battlefields**：戰場 ID 清單，例如 meadow、mountain、cave、millennium_lake。

混合多種怪物的既有區域會保留配置，**單一怪物隊伍**關閉；此時在 Habitat → Profile → Templates／Members 改進階組合。平常不用展開它。切換成單一隊伍只影響編譯結果，不覆寫原進階 Resource。

### 原生畫範圍

在 Inspector 按 **編輯出生／遊走／追擊範圍**，會直接選中對應的原生 **Polygon2D**。使用 2D 上方 Polygon 頂點工具拖點／加點／刪點，或直接拖動整個怪區。範本實例會自動啟用 Editable Children。

- 黃：SpawnArea，怪物出生。
- 綠：RoamingArea，日常遊走。
- 橙：PursuitArea，追擊上限。
- 需要排除孔洞：在該範圍下複製／新增 WorldRegionPolygon 子節點，設 **Is Hole**，用原生頂點工具畫洞。

保持 **出生 ⊆ 遊走 ⊆ 追擊**。形狀自交、孔洞超出、缺兵種或戰場 ID 無效，都會阻止試玩，仍可保存草稿。未選取的範圍不遮住畫面，也不再有不明藍點。

**兼容筆刷**：既有怪區可把 Shape Source 設成 Tile Brush，再按三個編輯按鈕選舊原生遮罩；新建怪區預設 Polygon，不會自動生成舊遮罩。Technical 留作歷史／兼容資料，平常不要修改。兩種模式只有選定的一種生效，避免「我畫了但遊戲不變」。

## 4．檢查、保存、試玩

**Project → Tools → 地圖 → 驗證目前地圖** → Ctrl+S → **F6**。檢查讀取未保存的畫筆／頂點，不只讀磁碟舊版本；首個錯誤會選中相關作者物件。F6 是真实遊戲的隔離試玩，不改正式角色／背包／世界存檔。F5 仍使用正式進度。

Play（F5／F6）驗證成功直接繼續，不彈「配置有效」視窗；只有錯誤阻止啟動並顯示原因。手動按「驗證目前地圖」才會顯示成功提示。再次 Play 會先關閉舊檢查視窗，避免已修好的錯誤視窗留下來。

如編輯器仍顯示舊 Dock，先停遊戲，Project Settings → Plugins 停用／啟用 World Authoring（或重開專案）；不用刪除 .godot、地圖或存檔。

**重生與正式進度提醒**：目前世界存檔保留已出生怪隊的成員及計時。更改模板不會把存檔中已存在的怪隊立即重抽；先 F6 看新配置，正式世界等後續重生套用。不要為預覽新怪而清空正式進度。

## AI／工程入口

`tools/project_context.ps1 -Topic authoring` → [D20契約](../specs/human_authoring.md) →本指南→指定場景。不要執行歷史 builder 重建整張地圖。備份在 `artifacts/workflow-2026-10-10/original-scenes/`；[驗證報告](human_authoring_validation.md)區分自動／Editor API 與人工操作。
