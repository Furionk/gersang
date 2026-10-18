# 原生製圖工作流驗證 — 2026-10-10

引擎：Godot 4.7.1.stable.official.a13da4feb，Compatibility。原場景／舊插件備份：`artifacts/workflow-2026-10-10/`。未清空正式世界或角色進度。

| 檢查 | 已執行結果 | 證據 |
|---|---|---|
| 六圖資料／完整地形／怪域／數值／原生座標／隔離配置 | 確認入口修改後91 passed，0 failed；含兩項核准資料隔離／嚴格範圍測試 | tests.json、human-approved.log |
| 全部既有戰鬥、技能、冰牆、角色、物品、HUD、世界圖和新工作流 | 確認位置後109 passed，0 failed；含18個子套件與移動場景 | full-approved.log、artifacts/world/results.json |
| 原生 TileMap 回歸 | 80 passed，0 failed | artifacts/world/native-tilemap-results.json |
| 真實 placeholder／未保存畫筆／舊tab／invalid→corrected build | 21 passed，0 failed | placeholder.log、artifacts/world/placeholder-build-results.json |
| 原生編輯器 API：Inspector／Polygon／TileMap／Sprite拖動、Undo/Redo、模板、新ID、保存重開 | 28 passed，0 failed；圖形 Editor 原生 MainLoop 亦通過、無崩潰 | editor-real-final.log、artifacts/world/native-editor-results.json |
| 非 headless MOVE 30／120 FPS | 40 passed，0 failed；無倒退幀，速度約130 world units/s | movement-render.log |

以上短檔名均位於 `artifacts/workflow-2026-10-10/`，另標完整相對路徑者例外。資料／Editor API 測試不是人工滑鼠驗收。

## 版本與失敗處理

河灣 town_door 的原生作者位置變成 (1561,3504)，平面為 (4284.5,2723.5)；本輪遷移原點是 (4800,1900)。先保留而未覆寫；當時全回歸106 passed／3 failed，三個套件均因同一入口位置不符合舊基準。使用者現已確認「是，保留新位置」，記錄 D20a 與 tests/world/approved_portal_edits.json。三個測試只在比較副本中套用這一筆明確核准位置，備份／正式場景都不改；目的地、半徑、其他入口與完整地形仍嚴格比較，未知坐標不會自動通過。主套件的入口功能測試讀目前作者位置，不硬編舊點，失敗結果也不再直接讀不存在 token 而掛住。確認後 HU 重跑91項通過；總回歸另見下方完成紀錄。

**D20a完成紀錄**：Godot 4.7.1 全回歸109 passed／0 failed（206052 ms），HU專項91 passed／0 failed，TileMap 80 passed／0 failed，文檔路由21 passed／0 failed，匯入無腳本錯誤。河灣場景前後 SHA256 均為 CDDF63128A1DF15D4599EA87B5ED1C0956DB97FC30E70FAB1F7789516A1779E8；本次只改測試核准資料、相關斷言和決策／報告，沒有再保存遊戲場景或正式進度。人工 GUI 閘門仍保持未驗收。

第一次總回歸發現舊 TileMap 遷移基準少了後續已授權的兩個阻擋取樣點；保留目前障礙，改為與本輪改造前的最新原生場景比對。新的 HU 專項另驗證所有 planar polygons 精確相同，不放寬為「任意差異可接受」。

第一次 Editor API 測試遇到 TileMap packed byte 排序不同；Undo 改驗實際格內容／数量，不把排序視為內容。範圍選擇測試確認選區子形狀顯示、其他區清除，而非把選區自己的子形狀誤判成應隱藏。

一次 `--editor --script SceneTree` 圖形測試完成28檢查後，退出時 C++ signal11，且啟動有 current_window=null；該紀錄不算乾淨圖形驗收。新增明確 opt-in `--native-editor-smoke` worker，在原生 Editor MainLoop 下執行同樣測試，避免用自訂 SceneTree 替換編輯器窗口生命週期。重跑28項與退出正常，見 editor-real-final.log。普通工作流不啟動測試 worker。

末次畫面檢查也移除了每個 Artwork 的鎖頭標記，保留原生 Group selection；常用怪物／人口欄位改非折疊分類，避免再次堆出不明點或把設定藏在多層折疊。

## 待你試用

- 原生 TileMap 實際滑鼠畫／擦、框選／圖樣。
- 縮放／平移後，拖 Polygon 頂點與整個怪區。
- 從 FileSystem 拖入三個模板，點建築選父物件。
- 入口往返及新地區獨立新增。F6 隔離，不用刪正式進度。

手動項目仍標示 **unverified**。目前重點是工具易用性，沒有重繪地表過渡素材、沒有改既有戰鬥數值或替換世界導航。
