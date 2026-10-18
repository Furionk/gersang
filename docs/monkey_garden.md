# 庭園捕猴 / Monkey Garden

河灣新增 `monkey_garden_region`，中心邏輯座標 (5000, 2700)，一隊五隻被動猴子。點擊接近後沿用五秒倒數，推近鏡頭、淡出，進入獨立 3D 庭園。首次取得瀏覽器游標鎖定需點擊「開始／繼續」。五隻全部捕捉即勝利。

## 操作

WASD 移動；滑鼠轉鏡頭；左鍵使用工具；右鍵面向鏡頭前方；Space 跳躍／二段跳；Ctrl 潛行；1–5／滾輪換裝；Q 上一件；Esc 暫停。雷達、螺旋槳、呼拉圈需按住左鍵。電擊棒與網每次按下揮一次。

工具順序：電擊棒、捕猴網、雷達、螺旋槳、呼拉圈。捕猴網無需先擊暈，可直接偷捕。藍燈平靜，黃燈搜尋，紅燈逃跑／反擊。

內嵌預覽若拒絕 Pointer Lock，可在暫停面板開啟「內嵌瀏覽器：右鍵拖曳鏡頭」。此模式也支援方向鍵調整鏡頭，WASD 仍控制移動。一般瀏覽器預設仍使用滑鼠鎖定；失焦或 Esc 暫停並清空輸入。畫面顯示 FPS，活動遊玩每十秒輸出 `MONKEY_WEB_PERF` 記錄。

10 HP＝1心，顯示保留小數。普通攻擊及陷阱扣10 HP，深水／深淵扣10 HP，熔岩扣20 HP。掉落回最後安全落腳點，已捕捉猴子保留；撤退／戰敗後重進重置五隻。勝利和撤退保留主角傷勢，戰敗主角在既有安全點復活；其他兵HP／MP保持入場資料。獎勵仍由SettlementService一次性處理。

## 編輯與整合

- 原生場景：`features/monkey/garden.tscn`；含已烘焙NavigationRegion3D、浮台跳躍連接、河流、熔岩、樹籬與陷阱。
- 可調參數：`features/monkey/data/default.tres`。`EncounterDefinition.monkey_profile` 空值維持普通戰鬥。
- `GameDirector` 負責倒數後分流、鏡頭、預載、結算與恢復；`MonkeyGarden` 管理玩家工具／碰撞／輸入／本場捕捉ID；`GardenMonkey` 管理感知、警戒、逃跑與動作。
- 3D場景只接收原始遭遇快照的五個敵人ID。不接受普通增援，也不加入其他戰鬥。
- 捕捉使用有限距離、方向、牆壁檢查與網頭掃掠；每次揮擊最多一隻，重複捕捉不計數。
- `tools/author_monkey_garden.gd` 和 `tools/add_monkey_habitat.gd` 是一次性來源記錄，拒絕覆寫；不要重跑覆蓋Artist編輯。
- `tools/render_monkey_world.gd` 從指定模型輸出八方向圖集。新增跳躍／受擊／捕捉使用程序姿態，不冒稱原始動畫具有這些片段。

## 素材來源

- 猴子：使用者提供 `W:/wMacSync/SynologyDrive/Blender Projects/Funny/Monkey.blend`。原檔未覆寫。專案GLB保留 Idle、Idle_Dance、Walking、Running 和內嵌貼圖。
- 捕猴員：Kenney Blocky Characters 2.0，character-a；https://kenney.nl/assets/blocky-characters 。CC0，授權檔 `features/monkey/assets/CHARACTERS-LICENSE.txt`。
- 樹木／岩石：Kenney Nature Kit，tree_blocks / rock_largeA；https://kenney.nl/assets/nature-kit 。CC0，授權檔 `features/monkey/assets/NATURE-LICENSE.txt`。
- 工具、地形、燈號、液體材質與短音效為本專案新增內容。沒有新增執行期插件或BGM。

## 驗證與建置

`tests/monkey_garden_suite.tscn` 驗證感知、捕捉、傷害和五猴勝利；`tests/monkey_encounter_suite.tscn` 以獨立磁碟存檔測試入場、三種結算、重入、保存重試及隊友保留。

`tools/request_monkey_web.gd` 讀取現有Web Export Studio設定，僅覆寫工作請求內輸出位置至 `artifacts/monkey/web`，保留所有既有建置檢查並追加捕猴兩套測試。不修改正式網站輸出位置、不部署網站。工作請求由既有 `addons/web_export/core/worker.gd` 執行。

第一版定位為可玩原型；手機／手把未列入驗收。測試證據與實際Web驗收狀態見 `artifacts/monkey/validation.md`。
