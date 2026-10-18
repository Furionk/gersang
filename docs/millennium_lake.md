# 千年湖：素材與可玩地城

本次新增原創「千年湖 · 沉祠湖境」，以提供的等角地城圖作風格參考。素材經 built-in image_gen 生成，再按現有原生 TileMap 與八向角色圖集格式接入；沒有裁取原作地圖素材。

## 遊戲內入口與示範

F5 重新執行遊戲，青嶺河灣主角初始位置附近、青嶺鎮南側有帶燈籠的石門「千年湖入口」。點門走近即可進入，入口邏輯座標 (4608,2464)；千年湖內入口石門可返回河灣，落點 (4736,2368) 位於觸發範圍外。

也可在 Godot 開啟 `features/world/data/millennium_lake.tscn` 按 F6 隔離試玩。此模式不保存正式進度。

千年湖有苔岩圍牆、幽青湖水、三條通往中央沉祠的木橋及湖岸苔石。湖水和岩壁不可走，木橋與中央島可走。東南湖岸只有一隊「千年湖守」，隊內恰好一名 Lv.6 原創龜靈怪物；被動遇敵，左鍵點怪接近，三秒倒數進入現有 RTT。新戰場沿用既有洞窟的障礙與戰鬥規則，地面使用本次新苔土地圖材質。撤退／結算按既有流程返回，入口與新增地圖不重置舊世界或角色。

## 可編輯資料

| 內容 | 原生檔案 |
|---|---|
| 地城地圖／TileMap／出生與活動遮罩 | `features/world/data/millennium_lake.tscn` |
| 河灣雙向入口作者節點 | `features/world/data/river_bay.tscn`：lake_door／lake_return／lake_landmark |
| 地形與遮罩 TileSet | `features/world/data/tiles/millennium_lake_{terrain,masks}.tres` |
| 原創湖守數值 | `features/units/data/monsters/lake_guardian.tres` |
| 八向 48 格裁切與腳底錨點 | `features/units/data/layouts/lake_guardian_layout.tres` |
| 湖守 Sprite PNG | `features/units/art/lake_guardian-v1.png` |
| 石門／岩壁／苔石／祭壇／橋 Sprite | `art/terrain/millennium_lake/props-v1.png`；對應 `data/scenery/lake_*.tres` |
| 四種材質與原生菱形圖集 | `art/terrain/millennium_lake/materials-v1.png`／`tiles-v1.png` |
| 獨立戰場 | `features/world/data/millennium_lake_arena.tres` |

原生 TileSet 是 64×32 菱形，包含 80 個材質變體及完整空白／地面／石路 Terrain 鄰接組合。派生 Tile PNG 是從生成材質以平面座標採樣，並非 AI 重新繪圖；正式地圖保存 cell data，不在遊戲啟動時重建。出生／活動／追擊遮罩連到 lake_guardian 怪區，人口 target_party_count=1，MemberRule min_count=max_count=1。改數值可直接在 Inspector 編輯 Resource；改湖岸／橋面需同步原生障礙和通行層。

生成提示詞、來源及實際尺寸在 `docs/millennium_lake_art_manifest.json`。素材 PNG 保留原 alpha，原始生成圖保留在 Codex generated_images。舊河灣 scene 備份在 `artifacts/millennium-lake/river_bay-before.tscn`。

## 驗證與證據

`tests/world/millennium_lake.tscn` 驗證材質重載、阻擋／橋面導航、入口往返、舊隊伍保留、單怪編成、圖集方向、真實 RTT 與撤退返回；`-- --capture` 另保存實際渲染截圖。測試使用獨立世界及記憶體存檔，不讀寫正式進度。

證據位於 `artifacts/millennium-lake/`：`results.json`／`render-results.json`、`entrance-in-game.png`、`lake-overview.png`、`lake-in-game.png`、`guardian-battle.png`。既有完整回歸使用 `tests/run_all.gd -- --all`；非 headless 移動回歸檢查 30／120 FPS。自動場景驗證與實際像素檢查已執行；人工滑鼠完整遊玩、編輯器逐格畫筆操作不冒充已驗收。

本次地城與渲染各 35 項通過、非 headless 移動 40 項通過。完整回歸首次 117 項通過／1 項失敗：入口套件舊檢查要求新增前的入口陣列完全相同；修為保留每個原有入口並允許新增後，該套件重跑 305 項通過，其餘完整回歸已通過。詳細結果與原始日誌保留在 `validation-summary.json`，不改寫初次失敗記錄。

一鍵製作工具 `tools/build_millennium_lake.gd` 是製作來源，不是開機程序；現有千年湖 scene 存在時保留它。首次製作先用 `-- --prepare` 寫出派生 PNG，完成 editor import 再執行作者工具。正式後續編輯以原生 scene 為準。
