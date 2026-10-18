# 世界／遭遇 v1 驗證

日期：2026-10-08。Godot 4.7.1.stable.official.a13da4feb，Windows，Compatibility。專案原有檔案、原 party_progress.dat、舊證據及來源文案保留；沒有新增 Git。

## 交付

- 6144×4096 外域、22 支怪隊、四個怪區，城內及兩層地城。
- 固定個體與成員快照、配置戰力、遊走／追擊／返巢、點怪接近、倒數及保留。
- 現有 RTS 接入快照，撤退／胜败／回圖、持久化一次性收據及出生槽。
- 完整 binary 世界保存、旧養成遷移、備份／暫存恢復及內容版本保護。
- 原生製圖 Dock、多邊形／洞、三區、模板、入口、ID 複製、隔離預覽、F6 真實試玩入口。
- spec 索引、來源快照／雜湊、變更 context 工具、統一回歸入口。

## 執行方式

```powershell
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --headless --editor --path . --quit
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tests/run_all.gd -- --all
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --headless --path . res://tests/world/integration.tscn
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --path . res://tests/world/integration.tscn -- --capture
./tools/spec_context.ps1 -Feature encounter
```

測試路徑与 context 隔離正式存檔。run_all 的失败退出碼非零，子測試同時檢查退出碼、引擎錯誤及 PASS 證據，防止解析失敗後誤報通過。

## 已驗證證據

核心 67 項資料／生命週期檢查通過：五個精確戰力 fixture、固定 seed、22 隊遊走、槽位占用、互斥、過期取消、保存失敗與同 candidate 重試、重複收據、窄路半徑、孔洞完整路徑、返巢、安全區、四圖配置驗證，以及戰前／提交後恢復和二層位置保存。

實際遊戲整合 22 項通過：同一批敵人進現有 RTS、撤退收據與保留同隊、回圖解鎖、城內及地城上下樓、同 tick 雙亡判敗。非 headless 渲染捕獲同時執行這些整合，圖像位於 artifacts/world（不匯入 Godot）。

既有回歸：戰鬥 72、技能 V2 64、養成 148、選兵輸入 14、視窗縮放 93、冰牆 AI 24、世界 HUD 40 項。舊世界測試已更換為 22 隊／受限網格／登錄 atlas／配置戰力，不再要求三個固定入口及未實作戰力。各組最終結果以 artifacts/world/*-engine.log 為準。

最終統一報告 **74 通過、0 失敗**（67 核心檢查及 7 組子回歸）。加上各組個別斷言和整合場景，共 67＋455＋22＝544 項檢查通過。報告：artifacts/world/results.json；匯入：import-final.log；核心：core-final.log；整合／實渲：visual-final.log；完整回歸：all-final.log。早期失敗日志保留，不等同最終結果。

## 效能與限制

測試 CPU 為 Intel Core i9-13900K（32 邏輯執行緒）。12 對 60 既有壓力場景已執行，量測為 headless 固定更新耗時，不是 GPU FPS 保證；最新 p95 位於 test_runner-engine.log。30／120 呈現上限的既有路徑耗時與攻擊次數比較保留。

畫面是原創素材的可玩示例，並非 100% 巨商或整張世界圖已建成。城池錨點及等角 atlas 轉換有自動檢查；所有岩石、海岸及場景密度仍需逐區人工校準。導航是保守網格，不做切角；相鄰通行多邊形接縫可能需合成一個連續外框，不能把有意保守判阻當成完美自然路徑。

**T17、T20、T18 的編輯器操作部分，以及完整 atlas 實走比對仍未人工驗收。** 解析／匯入與資料隔離測試不能代替滑鼠繪製、Undo／Redo、保存重開或另一位操作者獨立建圖。因此工具標記 implemented_gui_unverified，Phase 6 不標記全部完成。
