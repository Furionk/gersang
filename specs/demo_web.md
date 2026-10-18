# D38 — 十人展示版與無 BGM Web

此使用者決策覆蓋 D31/D32/D37 的固定七人、永久招募及新增角色初始 Lv1 設定；舊技能、儲存原子性和通行契約不變。

原生 `features/progression/data/demo_setup.tres` 是初始名單、傭兵等級、物品數量及工具開關權威。主角 Lv1；原六名傭兵、忍者、湖衣姬及 Malfory Lv25 出戰，鐵炮手 Lv25 在倉庫。合計十一種各一名，最多十人出戰。依最新要求，每人初始大補丸50粒、經驗之書25本，使用正常扣除，換兵不補貨；已有存檔不強制減少物品。Lv25 能力點不自動分配。

Web修正：全域GUI中文字體涵蓋世界Label；音效與語音使用Stream以支持生成WAV及音訊Bus。HTML工具列全螢幕只由真實點擊觸發，事件不得穿透遊戲。地圖選入口後「前往入口」仍走原生合法路徑再觸發，不能瞬移／放寬檢查。普通大補丸不再標為debug_only，提供使用快捷按鈕；全滿不消耗，明確顯示原因。

存檔採獨立 demo10-v3 命名空間，不讀取或覆寫原存檔。倉庫移動同一完整角色，先保存再發布，禁止重複招募。F2 隊伍／道具分頁提供普通操作；測試選項預設隱藏。數字1–9／0選取十人。

Godot4.7.1 Compatibility 單執行緒 Release，`web_no_bgm` 在任何音樂載入前停用 BGM。桌面 MP3、原畫、解析度、音效及語音保留；音樂安裝功能不在本期。動態目錄使用 ResourceLoader.list_directory 兼容匯出 remap。字型固定使用官方 OFL 完整 Noto Sans CJK TC Regular（art/fonts/NotoSansCJKtc-Regular.otf），涵蓋繁簡中文、日文等；不再裁成隨內容縮小的字集，也不依賴玩家系統字型。

Web、遊戲轉場及應用圖示使用使用者提供的 gersang3.png 原圖。匯出白名單排除 BGM、工具、插件、測試及生成證據。正式複製須完成驗證和大小確認，不 commit/push、不自動上線。使用者已接受161.169MiB及Gzip估算127.211MiB；Gzip須伺服器實際開啟才降低傳輸量。

驗證應分別記錄原生自動測試、瀏覽器真實操作及未完成項目，不能宣稱現有全套綠燈。歷史七人Lv1機制測試使用顯式隔離fixture；新十人設定由 demo_roster_suite 及 Release 瀏覽器另驗。

2026-10-14 缺字防回歸：完整CJK字型含44,810個支援字元；舊字集在現有內容缺315字。全平台全域Theme、HUD、RichText與勝利文字共用完整字型，保留舊檔作來源歷史。check_font_coverage.gd每次建置掃描common/features中的原生文字／內容（包含CJK擴展區）；任何缺字列出字元、Unicode與來源後拒絕匯出。font_coverage_suite另驗證實際30隊霍格愛茲怪物標籤和新增普通Label的字型繼承；渲染圖驗證繁簡中文與日文變體。未來超出完整字型的罕見字須先加入可分發fallback並通過閘門，不能以重做小字集或玩家OS字型解決。

2026-10-14 線上下載修復：伺服器的大 PCK 回應中途 ERR_CONNECTION_CLOSED，Godot 的 tracked ReadableStream 未把 rejection 傳回 startGame，原 HTML 又將183.2/184.0 MiB 四捨五入成100%。改由 download_loader.js 下載版本目錄中的2MiB靜態分段，每段30秒逾時／最多4次嘗試，檢查長度與SHA256後保留成功段落；手動重試只補失敗段落。完整WASM與PCK再驗證整檔SHA256後，將已驗證WASM交給engine.init、PCK ArrayBuffer交給preloadFile，沿用正式engine.start與原user://命名空間。下載至多顯示99%，接著顯示啟動階段；非同步啟動錯誤／90秒逾時必須顯示重新啟動按鈕，不能永遠停在LOGO。不清除玩家存檔。

tools/build_web.ps1 在匯出後呼叫 package_web_downloads.py，生成downloads/<內容版本>/manifest.json、93個左右的.bin與版本化loader.js；實際段數依建置大小而定。必須同步完整輸出目錄（包括downloads及.htaccess），不能只傳index.html/pck。根HTML使用no-cache；.htaccess只在/gersang內設定WASM MIME與關閉二進位分段的即時gzip，不動網站根設定。tests/web_download_loader_test.js是下載／HTML錯誤與重試閘門；web_download_http_test.js配合本機fault server驗證完整資料在真實HTTP斷線／損壞後重試。HTTP／WASM編譯測試不等於實際瀏覽器遊玩驗收。
