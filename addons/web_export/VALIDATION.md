# Web Export Studio 1.1.0 — 驗收紀錄

2026-10-16，Windows / Godot 4.7.1。本次針對 objects 審核、乾淨上傳包與編輯器進度條；下載器與遊戲內容未修改。

- 核心測試：48 項通過。新增實際位元組／檔案進度、raw/gzip 審核、缺失／損壞、隱藏雜檔與資料夾、外來 ownership、registry 超前時以 live HTML 為準、鎖互斥、取消、最新版本獨立上傳包、授權檔保留、既有／巢狀／父層目的地拒絕、來源內容不變，以及舊版缺塊與當前完整性的分離。
- JavaScript 下載／快取回歸：21 項通過。
- 小型 2D 專案完成原生匯入、Web 匯出、gzip 分塊、發布及自動 objects 審核。
- 獨立 Windows 編輯器實測：停用／重啟插件、基本／進階頁、活動進度條截圖、取消建置。面板另在無遊戲邏輯的 LiteralRock Node 下測試。
- 真實 Edge / WebGL / localhost HTTP：首次啟動、點擊、重載，39,516,155 bytes 暖快取全命中，分塊請求 0，JavaScript 例外 0。

本次不等同重新驗收所有瀏覽器或 iPhone，也不保證來源專案最後一次匯出後的改動已包含在現有輸出內。

以下保留 1.0.0 的歷史驗收，並非本次全部重跑：

## 1.0.0 歷史紀錄

驗證日期：2026-10-15 至 2026-10-16。基準為 Windows、Godot 4.7.1 stable、Compatibility renderer、單執行緒 Web。

## 已執行並通過

| 範圍 | 結果 |
|---|---|
| JavaScript 下載器 | 21 項：hash／長度、更新重用、損壞快取、quota、不可用儲存、重試、404、截斷、timeout、gzip 標頭、路徑／manifest 驗證、多頁面鎖、fetch 還原、原生啟動錯誤 |
| Godot 核心 | 23 項：分塊、gzip 重組、大小統計、來源／輸出隔離、發布與差異、相同版本零上傳差異、保留實際使用中的版本、清理、UI 建構 |
| 真實 HTTP／瀏覽器 | 8 組：404、hash 錯誤、缺 gzip 標頭、截斷、儲存不可用、多層子目錄與 warm cache、跨版本重用、兩個同時活躍頁面 |
| 跨專案 | 小型 2D、3D（匯入 glTF＋Shader＋UID 主場景）、動態 JSON／typed global class／preload 貼圖、巨商 |
| 編輯器 | 正常 Windows editor 啟動、停用／再啟用插件、基本／進階 UI 截圖、取消建置、渲染型專案檢查 hook |
| 失敗發布保護 | 不完整動態載入宣告與無效模板均拒絕；原入口 HTML hash 不變 |
| 來源設定保護 | 巨商 project.godot 與 export_presets.cfg 在插件匯出前後 SHA-256 一致 |

瀏覽器使用獨立測試 profile，沒有使用玩家日常 profile：Chrome for Testing 155.0.8059.79、Edge 155.0.4283.45、Firefox 158.0。驗收以 headless 真實瀏覽器／WebGL 執行，包含輸入、截圖、重載及實際網路事件；不是只模擬下載器。Chromium 測試停用擴充套件以隔離外部干擾。Edge 先前帶擴充套件的測試出現 AudioWorklet 問題，乾淨環境已通過；沒有宣稱任意擴充套件組合都相容。

跨版本樣本只重新取得 **5,612 bytes**，重用 **39,513,091 bytes**（均為解壓後資料）。巨商成功啟動及重載，第二次 **217,463,123 bytes** 全部命中快取，分塊 HTTP 請求 **0**。這些數字只描述測試樣本，不是所有專案的固定節省比例。

2D 範例點擊後的存檔值在重載後保留。3D 截圖確認 shader 方塊與匯入模型可見。巨商使用專案專屬模板、gersang_three.png 與原生無 BGM preset。原有巨商 Web gate（字體、持久化、入口、戰鬥修復、地城與移動等）亦已在本次工作執行通過；新插件沒有把這些遊戲規則寫死在通用核心。

## 可重現測試

開發測試需要 Node 與測試瀏覽器；普通使用者匯出不需要。

```text
node addons/web_export/tests/runtime.test.js
node addons/web_export/tests/create-fixtures.js <空的測試資料夾>
Godot --headless --path <測試資料夾>/two_d --script res://addons/web_export/tests/core_suite.gd
```

用各 fixture 啟用插件並匯出後，可使用 browser.test.js／firefox.test.js 驗證 localhost 載入與重載。browser_faults.test.js 自帶本機 HTTP 伺服器；第五個可選參數為上一版的入口 HTML，驗證跨版本重用。editor_driver.gd 只在隔離 fixture 註冊，不能在正式遊戲中啟用。repackage.gd 是開發輔助，用已驗證的原生輸出測試瀏覽器層變更；一般匯出使用 worker.gd。

專案完整證據位於 `artifacts/web-export-plugin/`：core-delivery.log、job-extension-check、editor-lifecycle-delivered.log、http-recovery-update、dynamic-browser-closure、imported-model-browser、gersang-edge-clean、gersang-chrome-preview、firefox-delivery。

## 範圍限制

這是第一階段交付，沒有提供第二階段 PCK 分組／按需載入 API，亦未提供第三階段 Atlas、Brotli 或自動精簡引擎編譯。Safari、手機、其他 Godot 版本、PWA、GDExtension、多執行緒尚未列入通過範圍。真實瀏覽器驗證不等於完整人工長時間遊玩或對所有內容的回歸測試；正式主機的 HTTPS／MIME／gzip 標頭仍須按實際部署驗證。

原生匯出篩選值依 Godot 的 [EditorExport 實作](https://github.com/godotengine/godot/blob/master/editor/export/editor_export.cpp)；插件在隔離副本中將舊工具寫入的 selected_resources 正規化為 resources，不改來源設定。
