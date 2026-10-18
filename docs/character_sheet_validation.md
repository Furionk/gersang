# 角色全畫面驗證 — 2026-10-09

引擎 Godot 4.7.1 stable / Compatibility，Windows；實際渲染使用 NVIDIA RTX PRO 6000 Blackwell Workstation Edition。圖片取自 Godot viewport，不是 UI 概念圖。

## 結果與證據

- 匯入：`artifacts/world/dossier-import-complete.log`，exit 0，無 script error。
- 完整入口：`tests/run_all.gd -- --all`，110項主入口檢查通過、0失敗；包含九個子場景與完整 MOVE 資料／場景回歸。子場景內部項目不是另外110個，也不以包裝檢查數冒充所有斷言的總數。證據 `dossier-all-complete.log` / `results.json`。
- 角色介面：`tests/character_sheet_suite.tscn`，69項、0失敗；headless及非headless原生 GUI 輸入均驗證。證據 `character-sheet-results.json` / `character-sheet-render-results.json` / `character-encounter-render.log`。
- 渲染移動：`tests/world/movement_regression.tscn` 非headless，40項、0失敗；30／120 FPS 下實際角色與鏡頭同步、速度與垂直 trace 無倒退／側向抖動。證據 `world-movement_regression-render-final.log`。移動實作沒有修改。
- 截圖：`tests/character_sheet_capture.tscn`，exit 0，1280×720、1920×1080、800×450、900×900裝備畫面，以及能力與公式試算画面。證據 `character_sheet_capture-delivery.log`。

## 角色介面覆盖

驗證肖像開單一 dossier、S/I互斥、Esc/F2／進戰清理、換兵立繪／技能同步、九裝備欄／十背包格、實際裝卸、背景不誤移動。真實 WorldContext 遭遇在 dossier 開啟時仍會關閉行囊、顯示3→2→1；Esc取消後恢復一般世界介面。原生視窗像素輸入會經過 Godot stretch 與 dossier 自身縮放，五種視窗比例均檢查欄位可點選與不越界；減傷輸入不遮住相鄰標籤。

配點驗證 +1、Shift+100、餘點19時只分配19、零點／非法拒絕、原子 changed 一次、中文公式及技能傷害立即刷新。角色舊四欄裝備保存恢復至九欄而不失去物品或配點，原枚舉0–3不變。

技能驗證兵種＋裝備聯集及同ID去重、無技能清空、11個可配置技能捲動及第三列實際可選取、只查閱不施法、公式錯誤提示，以及回復／召喚／冰牆／暴擊不同說明。固定試算可見、減傷僅一次，預覽不更改角色數值。

已實際查看渲染截圖：全身不裁切、裝備依身體位置排列、技能文字與計算區／物品格分離；方形視窗畫布置中，其餘區域為遮罩，不拉長立繪。

## 執行入口

```powershell
Start-Process -FilePath 'R:\App\Godot_v4.7.1-stable_win64.exe' -WindowStyle Hidden -Wait -ArgumentList @('--headless','--path','"W:\wMacSync\SynologyDrive\Godot Projects\gersang"','--script','res://tests/run_all.gd','--','--all')
```

角色／截圖可各自用 `res://tests/character_sheet_suite.tscn` / `res://tests/character_sheet_capture.tscn` 啟動；後者不能加 headless。所有測試自動隔離玩家存檔。

## 邊界

這是程式注入原生 GUI 輸入加真實渲染證據，不冒充人工鼠鍵試玩，也不是原版像素級美術驗收。只沿用既有原創立繪／邊框；此輪沒有新增其他装備的數值或圖片。世界製圖外掛的舊人工驗收閘門保持未驗，不因這次 UI 通過而改狀態。
