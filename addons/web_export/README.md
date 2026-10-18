# Web Export Studio 1.1 — Godot WebGL 匯出插件

這是分階段方案的 **第一階段**：通用匯出、分析、內容 hash 分塊、gzip、瀏覽器快取與版本發布。一般遊戲不需要修改程式。安裝與正常使用只需要 Godot 4.7.1 及其對應 Web export templates；Node 僅用於開發測試。

## 安裝及開始

1. 安裝 Godot 4.7.1 及相同版本的 Web export templates（Editor → Manage Export Templates）。專案使用 Compatibility renderer。
2. 解壓 ZIP，把 `addons/web_export` 放在專案根目錄；結果應是 `project.godot` 旁有 `addons/web_export/plugin.cfg`。已有舊版時先停用插件，備份並替換整個 `addons/web_export` 資料夾，再啟用。
3. 在 **Project → Project Settings → Plugins** 啟用 **Web Export Studio**。
4. 開啟 **Project → Tools → Web Export Studio**。
5. 選擇已有的 Web preset，或使用 Default Web；選輸出位置，按「分析」，再按「一鍵匯出」。

不同專案不要複製巨箱的 `web_export.cfg`，首次啟用會產生自己的 project ID；模板留空即可使用通用網頁，LOGO 可選自己的圖片。設定保存於專案的 `web_export.cfg`，請納入自己的版本管理。插件不修改原本 `export_presets.cfg`；在 `.godot/web_export/jobs/` 建立獨立副本，使用 Godot 原生匯入及匯出，驗證成功後才發布。更改專案內容後先儲存場景／Resource，再匯出。

輸出必須是專用空目錄，或已由同一 project ID 管理的目錄；專案內只接受 `build/` 或 `artifacts/`。不要直接選擇既有手動部署目錄。既有巨商匯出流程仍可使用，新插件可先輸出到另一目錄驗收。

## 基本與進階設定

- 網頁模板：留空使用內建；也可選擇專案內或外部 HTML。複製 `web/shell.html` 修改樣式即可。
- LOGO：選擇 PNG、WebP、JPEG 或 SVG；不改遊戲的 project icon。
- 分塊：1–4 MiB，預設 2；下載併發 1–6，預設 3。
- 快取：預設開啟，容量 512 MiB；以 project ID＋網站路徑隔離。更換 project ID 視為新的快取空間。
- 壓縮：預設 none。gzip 只對壓縮後更小的分塊啟用，需要主機送出正確標頭。
- 預算：首次下載／當前版本伺服器體積超出設定時警告；不以強制降畫質滿足預算。
- 診斷：可選擇在遊戲角落顯示解壓後下載與快取數量；預設關閉。
- 精簡匯出：預設關閉。啟用後會使用相依圖；涉及 runtime 路徑時，必須指定 Include 檔案／目錄並確認已宣告完整。
- Include：每行一個 `res://` 檔案或資料夾，可納入 JSON、CSV 等原生 Resource 以外的資料。
- Exclude：每行一個匯出排除規則。排除必要資源可能導致遊戲缺件，請先看分析報告。

分析報告列出 main scene、Autoload、原生 preset、全域 class_name 腳本、靜態文字路徑與明確指定內容的相依關係及來源。全域類別採保守保留，以避免 typed GDScript 在執行時缺少類別；因此精簡模式不保證移除每個未使用的類別。程式動態組合路徑無法被一般靜態分析完整推導；請宣告必要目錄。RGBA 貼圖估算不包含 mipmap、GPU 壓縮及資源副本。

## 快取行為

分塊以 SHA-256 定址；下載及讀取快取時都驗證大小與內容。整次啟動固定使用同一份 manifest。更新版本時，相同 hash 可重用；未改動 WASM 不需重新下載。整個 PCK 固定分塊不保證只修改一張圖就只改一塊，報告會顯示實際上傳差異。

快取不可用、容量不足或瀏覽器清除資料時會重新下載。Web Locks 可用時，活躍頁面持有共享鎖；自動淘汰只在沒有其他活躍頁面使用快取時進行，避免多分頁互刪。沒有 Web Locks 時跳過自動淘汰，滿額後繼續遊戲而不增加快取。玩家 Godot 存檔與此快取分開，插件不清除它們。

首版不提供離線啟動或 PWA；每次仍需取得網頁及版本資訊。首次啟動仍需完整下載主要 PCK 與 WASM。

## 發布、FTP 與清理

`build-report.json` 提供：

- `upload_files`：當前版本完整上傳清單。
- `delta_files`：相對上一個本機版本的變更清單；只有確定伺服器已有上一版時才使用。
- `chunk_reuse_percent`：相對上一版，按傳輸位元組計算的內容分塊重用率。
- `server_bytes`：當前版本所需檔案體積，不包含保留的歷史版本。
- `first_transfer_bytes`：包含 sidecar 的首次傳輸上限估算；實際請求可能較少。
- `delta_transfer_bytes`：差異檔案的磁碟體積；PCK/WASM 分塊已依選定壓縮計算。
- `loader_memory_estimate_bytes`：組裝緩衝估算，不是瀏覽器或 GPU 峰值記憶體實測。

上傳 `objects/`、當前 `releases/<版本>/` 與 `.htaccess`，**最後上傳 `index.html`**。以報告清單為準，不需上傳開發記錄。發布過程保留舊入口；失敗不換新入口。取消於安全步驟生效，提交中的短暫發布交易會完成。

「清理舊版本」先預覽，再確認；保留當前及上一個版本，只刪除登記擁有、hash 未被外部修改、且不再被保留版本引用的檔案。發布與清理互斥。不要上傳 `web-export-state.json`、`build-report.json`、`.gdignore`、`index.html.previous` 或工作目錄。

## 1.1：objects 完整性、乾淨上傳包與進度條

- **檢查 objects**：從實際 `index.html` 的 hash 找到正在使用的版本，再驗證對應 manifest、每塊大小及 SHA-256；gzip 同時驗證傳輸檔案與解壓後內容。隱藏檔案、意外子資料夾與連結路徑也會列出。
- 結果分為目前版本、保留舊版、可清理舊塊、未知內容、不安全路徑、缺失、損壞及清單錯誤。**「目前分塊有效」與「目錄只有目前版本」是兩個判斷**，不會把保留版本誤稱為乾淨目錄。
- 每次「一鍵匯出」完成後自動執行同樣檢查，結果保存在 `build-report.json` 的 `object_audit`。這是對已匯出版本的驗證；要包含最新遊戲修改，先儲存再重新匯出。
- **乾淨上傳包**：選父資料夾，插件另建唯一名稱的 `web-upload-*` 子資料夾，只複製目前版本引用的分塊及發布檔，逐檔核對 hash，再驗證新 `objects/` 確實沒有其他內容。既有來源目錄及保留版本不會被刪除。
- 常見根目錄授權檔 `LICENSE`、`LICENSE.txt`、`LICENSE.md`、`COPYING`、`COPYING.txt`、`*-LICENSE.txt` 會驗證並保留。其他自訂 sidecar 應由原生匯出器產生並列入發布清單，未登記的任意檔案不會混入。
- 新包內 `upload-files.json` 是完整上傳順序，`index.html` 排最後；`web-export-state.json`、`upload-files.json`、`.gdignore` 是本地工具資料，不需上傳。**FTP 覆蓋上傳不會自動刪除伺服器舊 objects**；清理遠端舊檔仍須依已發布／保留版本另外處理。
- 檢查與複製在背景工作程序執行，與發布／清理互斥，可取消；失敗留下的新上傳資料夾不可使用。未知檔案不會自動刪除，也不會追蹤連結到其他目錄。
- **進度條**顯示當前階段的實際檔案數或 MiB：來源快照、分塊、發布、驗證、上傳包複製。Godot 原生掃描、專案測試、匯入／匯出沒有可靠百分比時顯示活動進度條；這不是整體剩餘時間估計。

若 `index.html` 被手動修改，與登記 hash 不符，檢查會停止並說明原因；不要只修改 registry 的 hash 來繞過驗證。將修改放回模板後重新匯出，建立一致的新版本。

## gzip 主機設定

內建 localhost 預覽支援 gzip；輸出 `.htaccess` 適用允許相關設定的 Apache。正式主機必須將 `objects/*.bin.gz` 回傳為 `Content-Encoding: gzip`，資料由瀏覽器解壓後驗證。缺標頭會明確報錯，不嘗試啟動損壞的引擎。不要對已壓縮檔再次動態壓縮。

Nginx 可在該遊戲網站設定相應規則（依自己的 location/root 調整）：

```nginx
location ~ /objects/[a-f0-9]{64}\.bin\.gz$ {
    default_type application/octet-stream;
    add_header Content-Encoding gzip;
    add_header Cache-Control "public, max-age=31536000, immutable";
    gzip off;
}
```

無法設定主機標頭時選 none。正式環境使用 HTTPS；預覽伺服器只綁定 127.0.0.1，並隨插件停用而停止。

## 自訂模板契約 v1

保留 `WEB_EXPORT_SHELL_V1`、`$GODOT_URL`、`$GODOT_CONFIG`、`__WX_META__`、`__WX_RUNTIME__`、`__WX_LOGO__`、`__WX_TITLE__`，以及範例中的固定元素 ID。Godot script tag 使用 `src="$GODOT_URL"`。不要自行再次啟動 Engine 或註冊另一套下載／Service Worker。

模板可以改布局、色彩與文字，但啟動、下載、驗證及重試交由 runtime 負責。引擎啟動逾時會提供重新載入選項；不顯示假的下載 100%。

## 專案檢查擴充與 CLI

`web_export.cfg` 的 `checks` 可設定 Godot 測試 scene 或 script。每項檢查預設 headless，可用 `"headless":false` 執行需要實際渲染的檢查；要求退出碼 0、沒有 Godot ERROR，並可要求輸出包含成功標記。例如：

```ini
checks=[{"scene":"res://tests/smoke.tscn","expected":"SMOKE_PASS"}]
```

檢查在原專案執行，測試作者必須自行使用隔離的存檔。巨商的專屬無 BGM 設定沿用其原生 Web preset；字體、入口及戰鬥等檢查屬專案檢查，不寫死在通用插件。

CI 可呼叫 `core/worker.gd`，傳入 JSON：`{"job":"絕對工作目錄","profile":{...完整設定...},"action":"build"}`。使用 `Godot --headless --editor --path 專案 --script res://addons/web_export/core/worker.gd -- 請求JSON --web-export-child`。也支援 `"action":"audit"`，或 `"action":"upload","destination":"新的絕對目錄"`。工作目錄產生 status、result、analysis 及 native import/export logs。一般使用者使用介面即可。

## 版本與範圍

首版基準：Godot 4.7.1、Windows、Compatibility renderer、單執行緒 WebGL 2、GDScript。會拒絕需要額外部署支援的 PWA／Threads／GDExtension 預設。自訂 native export template 沿用原生 preset，仍需與引擎版本相容。其他引擎版本、Safari、手機尚未列為驗證支援範圍。

第二階段的分組 PCK／按需載入 API，以及第三階段的 Atlas、Brotli 與自動編譯精簡 WASM 尚未實作；目前沒有假設它們已可用。移除／停用插件後可繼續使用原生匯出預設。

## 開發測試

`tests/runtime.test.js`：網路、hash、快取、配額、多分頁及 fetch 還原。
`tests/core_suite.gd`：原生分塊／gzip、發布、差異、路徑與清理。
`tests/browser.test.js`：獨立 headless Chromium profile 的真實 WebGL 啟動、點擊及重載。
`tests/firefox.test.js`：獨立 Firefox profile 的相同驗收。
`tests/editor_driver.gd`：只供隔離 fixture 註冊，驗證編輯器停用／啟用、面板及取消；不在正常插件啟動時執行。

## 巨商專案範例

選 `Web Demo No BGM` preset、`res://features/web/export_studio_shell.html` 模板及 `res://gersang_four.png` LOGO。專案模板保留 gersangWeb 音效測試／全螢幕橋接；它不包含在通用 ZIP。可把專案的 `features/web/studio_profile.example.cfg` 複製為根目錄 `web_export.cfg`，取得這些設定及專案檢查。巨箱的 `Web Export.cmd` 可直接開啟插件。

工作副本保存在 `.godot/web_export/jobs/`，可能佔用較大本機空間。確認沒有建置正在執行後，可以刪除已完成的工作資料夾；不要把它們上傳。

第一階段驗收紀錄請看 `VALIDATION.md`。測試依賴 Node／測試瀏覽器，正式匯出不需要。
