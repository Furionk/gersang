# 戰鬥 V2 驗證結果

更新至2026-10-08；下方保留前次結果。Godot 4.7.1.stable.official.a13da4feb。

2026-10-13整理註：下文舊根日誌已保留於 `artifacts/history/2026-10-13/root_logs/`，舊 `tests/*.png` 截圖於同次歸檔的 `test_screenshots/`；精確原路徑對應見該目錄的 `manifest.json`。歷史測試數字保持原意，不代表今天重跑。新生成結果改放 `artifacts/tests/<suite>/`。

## 大地圖巨商式 HUD（2026-10-08）

採附圖1024×768版面比例，保留可伸縮視窗，世界與戰鬥使用不同HUD。已接入左側獨立頭像與實際HP／MP／剩餘配點標記、右側選兵立繪、左下主角等級／經驗與待定欄位、中間訊息／本機文字輸入、右上繪圖地圖／主角標記，以及右下視窗圖示和右邊記事簿按鈕。世界開發者頂條隱藏，戰鬥HUD不改結構。無飽食度。

本輪生成三張原創PNG，內建image_gen模式，原檔保留、版本化拷貝至 `art/ui/classic/`；Godot使用貼圖框和原生控制項，並驗證atlas索引、透明邊緣、圓形裁切和縮放文字。提示詞及完整路徑見 `docs/world_hud_art_manifest.json`。**沒有像素級比較可支持100%原作還原**；頭像／立繪／框体／地圖均為參考後重繪。原場景地板與建築沒有在這輪全面重做。

- WorldHUD專項 **40項通過、0失敗**：`world-hud-suite.log`，`GERSANG_WORLD_HUD_PASS`。覆蓋獨立且不同的七個角色美術、12格與5預留格、HP／MP／配點、真實滑鼠輸入選兵與＋、右側立繪與背包頭像、離線商團／朋友、設定與四個試玩入口、M、主角地圖座標、Enter本機log字面安全、待定數值、四比例縮放及戰鬥／行旅切換。
- 養成／背包回歸 **148項通過**：`progression-world-hud-regression.log`。測試改用新頭像條，而非點擊已隱藏的舊介面。
- 戰鬥V2 **64項通過**：`v2-world-hud-regression.log`。
- 行旅／戰鬥流程 **72項通過**：`combat-world-hud-regression.log`。世界設定按鈕的測試坐標取自新右下按鈕，而非舊頂部固定位置。
- 實際GPU渲染 **通過**：`world-hud-visual.log`／`GERSANG_WORLD_HUD_VISUAL_PASS`；1024×768、1280×720、1920×1080、800×450、900×900。已目視检查1024基準、完整繪圖及立繪介面，早期圖集對應／取樣錯位已修正，最終截图在 `tests/world-hud-*.png`。

以上最終日誌均無SCRIPT ERROR／ERROR／WARNING。輸入事件由引擎注入；渲染測試的外部輸入關閉，以避免操作其他應用影響測試窗口。不是OS真人互動驗收。

戰鬥力、信用與銀兩只保留欄位；商團、朋友、交易與PVP未有伺服器。聊天只保存本次本機訊息，沒有送到其他玩家。地圖繪圖對應原型座標，不表示整張地理世界已可遊玩。這些限制亦在遊戲對應視窗中說明。

```powershell
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --headless --path 'W:\wMacSync\SynologyDrive\Godot Projects\gersang' res://tests/world_hud_suite.tscn
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --path 'W:\wMacSync\SynologyDrive\Godot Projects\gersang' res://tests/world_hud_capture.tscn
```

邊框與縮放字體使用[Godot StyleBoxTexture](https://docs.godotengine.org/en/stable/classes/class_styleboxtexture.html)及[SystemFont](https://docs.godotengine.org/en/stable/classes/class_systemfont.html)的原生能力。

## 能力／背包與永久數值（2026-10-08）

已完成：行旅肖像／1–7選兵，S左側能力、I右側背包、兩面板可同開／獨立關閉，Esc優先關閉、進戰關閉及GUI點擊隔離。十格背包、四格裝備、補HP／MP、負重／堆疊驗證；裝備移除與配點可更新實戰。主角及六名傭兵独立XP、Lv.100上限、每級4配點、勝利結算與永久存檔。

XP採指定資料站累計欄Lv.1–100；每個等級門檻與前一點邊界都有測試。資料站下一級欄與累計欄存在少量不一致，使用累計原值：[來源](https://www.52jushang.com/qita/zhandou_exp.asp)。數值係數、戰後分配、測試裝備不是原作量測，詳見 `docs/combat_v2.md`。

**數值專項148項通過、0失敗**：`progression-suite.log`／`GERSANG_PROGRESSION_PASS`。含XP邊界／多級／封頂、配點、能力推導、中文幸運技能公式、實際隨機普攻／MISS／暴擊0–100%／物理減免／法抗（含即時雷擊與持續火龍的實際HP結果）、背包交易完整性與資料隔離、存檔拒絕非法／未來版本，以及引擎輸入路徑的世界選兵、S/I切換、裝備按鈕、Esc、戰鬥S/I不衝突和勝利不重複給XP。

**真正兩次程序存檔測試通過**：`progression-save-write.log` 的 `GERSANG_PROGRESS_PROCESS_WRITE_PASS`、新進程 `progression-save-read.log` 的 `GERSANG_PROGRESS_PROCESS_READ_PASS`。第二程序從磁碟讀回火銃手Lv.9／1230XP、幸運配點、短刃、飯糰剩餘數量及HP／MP，並非只重用原有記憶體物件。測試以唯一命名user://檔進行，未讀寫正式 `party_progress.dat`。

**既有 V2 64項、完整流程72項通過**：`v2-progression-regression.log`、`combat-progression-regression.log`。一擊必殺0%／100%測試隔離了新加入的武器隨機幅度、自然暴擊與命中抽值，仍驗證固定技能公式；隨機層的實際HP結果由新專項獨立驗證。

石槌山冰牆AI回歸 **24項通過**：`ice-wall-progression-regression.log`，確認新命中／傷害層下仍可近身反擊、牆移除後續追和清理。

**Editor公式試算通過**：`progression-formula-editor.log`／`GERSANG_EDITOR_FORMULA_PASS`，新增幸運、固定防禦、物理抵抗與法抗欄位，減免按技能類型計算。

**五種實際GPU視窗渲染通過**：`progression-visual.log`／`GERSANG_PROGRESSION_VISUAL_PASS`。1280×720、1920×1080、1024×768、1720×720、800×450，左右面板完整且不互相重疊。已目視檢查兩面板與背包間距；PNG位於 `tests/progression-<解析度>.png`。测试角色的装备及经验为受控预览数据，不是玩家正式存档。

上述最終日誌沒有SCRIPT ERROR／ERROR／WARNING。GUI操作測試為引擎注入的按鍵／滑鼠事件，非OS真人操作驗收。招募、轉職、正式掉落、交易、信用度與多人沒有加入；倒下傭兵戰後以1HP復甦供本機試玩。

重跑：

```powershell
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --headless --path 'W:\wMacSync\SynologyDrive\Godot Projects\gersang' res://tests/progression_suite.tscn
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --path 'W:\wMacSync\SynologyDrive\Godot Projects\gersang' res://tests/progression_capture.tscn
```

## 石槌山冰牆 AI 修正（2026-10-08）

玩家回報冰牆阻路後怪物停住，其他我方單位靠近亦不反擊。已在石槌山實體通道重現：舊版等待受阻12秒時，怪物停在 `(685.4156, 540)`，同一測試中反覆結束命令／發送受阻訊息295次；冰牆自然消失後仍在原地，攻擊次數0。它同時保留原本遠處的存活目標，忽略新靠近的其他友軍。原始診斷見 `ice-wall-ai-before.log`；初次冷啟動的導航就緒檢查另有測試準備問題，已改為等待實際導航同步，因此不可將該日誌的全部失敗項數視為產品缺陷數。

修正 `TacticalUnit` 的受阻處理：追擊／施法接近不再直接 `_finish()`；新增可檢視的 `blocked` 狀態，重設卡住計時並錯開重試，導航 map iteration 或目的地改變可解除等待。抵達不可達路徑端點不再每幀反覆請求移動。普通移動仍在最近可達位置完成命令並保留既有不可達提示。

怪物每三秒的全場索敵不變。原鎖定目標仍存活但不在攻擊範圍时，每0.24秒做一次局部近身檢查，可轉向已在攻擊範圍的另一名友軍；原目標在攻擊範圍時不搶換目標。

**修正後實際 GPU 專項：24項通過、0失敗**，`ice-wall-ai-rendered.log`，標記 `GERSANG_ICE_WALL_AI_PASS`。三次石槌山獨立戰場、真正冰牆技能及碰撞：驗證第三秒才首次索敵、牆仍存活時不穿牆、不刷屏／反覆結束命令、15秒自然到期後實體通過山道並攻擊、對非原目標近身反擊、死亡目標補找、指定攻擊命令受阻時保留、手動移除冰牆後恢復，以及離場清理。較早 headless 版本為19项通过；最终渲染版本增加了指定攻擊兩项及第三場準備檢查三项。

V2 專項重跑 **64項通過、0失敗**：`v2-ice-wall-fix.log`。本輪渲染專項與 V2 最終日誌均沒有 SCRIPT ERROR、ERROR 或 WARNING。

行旅／控兵／戰鬥回歸重跑 **72項通過、0失敗**：`combat-ice-wall-regression.log`，標記 `GERSANG_ACCEPTANCE_PASS`，亦無腳本錯誤或警告。首次回歸曾因普通不可達移動的提示改為「被阻擋」而失敗；已恢復原有「不可達」提示，維持原測試條件重跑通過。

已目視確認實際渲染：`tests/ice-wall-ai-blocked.png`（牆仍封路）、`tests/ice-wall-ai-recovered.png`（牆到期後抵達原目標並造成傷害）、`tests/ice-wall-ai-retaliation.png`（牆仍存活时近身反擊）。這是受控固定更新場景，不宣稱已覆蓋玩家所有48秒實戰的隊形／位置。

重跑：

```powershell
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --path 'W:\wMacSync\SynologyDrive\Godot Projects\gersang' res://tests/ice_wall_ai_regression.tscn
```

導航同步與路徑端點處理參考：[Godot NavigationAgent 官方說明](https://docs.godotengine.org/en/stable/tutorials/navigation/navigation_using_navigationagents.html)。

## 視窗適配（2026-10-07）

已改為 `canvas_items / expand / fractional`：以 1280×720 為基準等比例縮放，允許拖曳／最大化，最小獨立視窗 800×450。GUI 改用原生錨點：頂／底欄全寬、技能靠右下、世界小地圖靠右上、彈窗置中；中央紀錄區隨寬度延展。邊緣捲動使用實際 viewport 尺寸，不再寫死 1280×720。场景使用 nearest filtering，邏輯座標與速度保持不變。

**實際 GPU 視窗測試：96 項通過、0 失敗**。`tests/window_resize_regression.tscn` 在同一次獨立遊戲進程反覆改變原生 Window.size：800×450、1280×720、1920×1080、1024×768、1720×720、900×900，再返回1280×720。確認無長寬比拉伸、介面貼邊／置中、預約列不裁切、全隊技能不重疊、邊緣捲動、視窗座標輸入經引擎縮放後選兵及 GUI 隔離。滑鼠事件由引擎注入，並非 OS 真人滑鼠驗收。

日誌 `window-resize-regression.log`，標記 `GERSANG_WINDOW_RESIZE_PASS`。Compatibility renderer：NVIDIA RTX PRO 6000 Blackwell Workstation Edition。實際 framebuffer 截圖已目視檢查：`tests/resize-800x450.png`、`tests/resize-1024x768.png`、`tests/resize-1720x720.png`。

另重跑選兵輸入回歸 **14 項通過、0 失敗**：`selection-input-resize.log`。本輪最終兩份日誌沒有 SCRIPT ERROR、ERROR 或 WARNING。未重新量測戰鬥傷害／壓力效能；下方保留前次數據。

自由縮放不等於整數 pixel-perfect：非整數倍率仍可能讓來源像素的螢幕寬度不均。此版優先保留任意視窗填滿與等比例顯示，不承諾像素整數對齊。

重跑（不要加 `--headless` 才會產生實際渲染截圖）：

```powershell
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --path 'W:\wMacSync\SynologyDrive\Godot Projects\gersang' res://tests/window_resize_regression.tscn
```

引擎縮放與編輯器內嵌預覽的依據：[Godot 官方多解析度說明](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)。

## 戰鬥點選修正（2026-10-07）

玩家實際點兵發現 `selection_controller.gd` 將三元運算產生的一般 `Array` 傳入 `select_ids(Array[int])`，造成執行期型別錯誤。已改為明確建立 `Array[int]`，有命中單位才加入 ID；空白取消也使用同一型別。

滑鼠命令改用事件自身座標轉換至場景座標，避免依賴稍後的系統游標位置。新增 `tests/selection_input_regression.tscn`，透過 `Viewport.push_input` 走完整 GUI／未處理輸入路徑，而非直接呼叫選取函式。

**14 項通過、0 失敗**：單選、對應技能欄、Shift 加選／移除與技能合集、替換選取、Shift 空白保留、空白清空、拖框、鏡頭移動後點選、GUI 點擊隔離，以及右鍵移動／指定攻擊。日誌：`selection-input-regression.log`，結束標記 `GERSANG_SELECTION_INPUT_PASS`。這是引擎輸入事件回歸，不等同真人滑鼠或 OS 自動化驗收。

修正後重跑 V2 專項：**64 項通過、0 失敗**，日誌 `v2-selection-fix.log`，結束標記 `GERSANG_V2_PASS`。兩份本輪最終日誌沒有 SCRIPT ERROR、ERROR 或 WARNING。

此前 64 項 V2 測試直接呼叫選取函式，沒有覆盖此次出錯的滑鼠單選分支；下列原驗證結果不能當作該分支已驗證的證據。

重跑：

```powershell
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --headless --path 'W:\wMacSync\SynologyDrive\Godot Projects\gersang' res://tests/selection_input_regression.tscn
```

## 結果

- V2 專項：**64 項通過、0 失敗**；結束標記 `GERSANG_V2_PASS`。
- 行旅／控兵／戰鬥回歸：**72 項通過、0 失敗**；依 V2 自身即時暴雷和三秒敵方索敵規則更新舊測試條件。
- 實際 Editor Inspector：`GERSANG_EDITOR_FORMULA_PASS`，確認外掛能在選取暴雷技能資源後產生「基礎 40.000」的公式結果。
- 實際 GPU 渲染：`GERSANG_V2_VISUAL_OK`；Compatibility renderer，NVIDIA RTX PRO 6000 Blackwell Workstation Edition。
- 上述最終日誌沒有 SCRIPT ERROR、ERROR 或 WARNING。

歷史完整結果：`artifacts/history/2026-10-13/test_results/v2-results.json`、`acceptance-results.json`。這不是現版全套通過聲明。
日誌：`v2-suite-final.log`、`v2-regression-final.log`、`v2-formula-editor.log`、`v2-visual-final.log`。

## 驗證範圍

動態單選／多選合集、同技能合併與多施法者、無選取清空、被動禁按、不擁有技能不瞄準、切換選兵清理瞄準、圖示尺寸不膨脹。

公式中文／英文別名、括號、除零與未知變數、禁止函式、負傷害、armor只套一次，以及任意兵種配置一擊必殺。

暴雷在一個邏輯tick起動、一秒五波且每目標只命中一次；車輪跟隨、16次tick和目標死亡終止；地震四次傷害、結束才减速、刷新与恢复原速；火龍直線寬度、傷害間隔和不同呈現間隔的一致性。

箭魂獨立屬性、不占永久編隊、可選取、每施法者上限與超時銷毀；冰牆占位拒絕、實際碰撞、導航、重疊引用、生成／移除、**友軍與敵軍地面實體实际绕牆、飛行實體实际通過**。

第三秒首次全場索敵、鎖定目標後持續追擊，以及離場清理持續技能／召喚／狀態／冰牆。

## 本機採樣

| 測量 | 結果 |
| --- | --- |
| 火龍，30 FPS 呈現間隔 | 10 ticks，受測目標傷害 30 |
| 火龍，120 FPS 呈現間隔 | 10 ticks，受測目標傷害 30 |
| 活動壓力場景 | 十二友軍＋六十敵人，並同時存在暴雷、地震、火龍、車輪和冰牆 |
| 壓力採樣結束存活單位 | 72 |
| Headless 幀耗時 P95 | 10.973 ms |
| 採樣物理處理時間 | 3.374 ms |

火龍10個傷害時間點中，靜止目標只有位於移動火龍／拖尾範圍內的3次命中，因此合計30，而非全壽命100傷害。這驗證了空間範圍而不是無条件扣血。

物理繞牆驗收時限按導航路徑長度與兵種移速計算，並保留兩秒避讓餘量；較慢怪物會繞過冰牆和既有岩區，不能用與較快友軍相同的固定十秒判斷。

壓力數字為本機headless CPU／排程採樣，不是GPU benchmark，也不保證其他電腦的幀率。原作手感與數值仍需玩家試玩校準。

## 視覺交付

`tests/v2-selected-preview.png`、`v2-union-preview.png`：單選只看該兵技能，多選合集与被動／自動標示。
`v2-quake-preview.png`、`v2-blast-preview.png`、`v2-wheel-preview.png`、`v2-dragon-preview.png`、`v2-summon-preview.png`、`v2-ice_wall-preview.png`、`v2-critical-preview.png`：七種實際渲染。
`v2-settings-preview.png`、`v2-sequence-preview.png`：可捲動的全部技能鍵位與每個技能的預約順序。

原創圖集及提示詞：`docs/v2_art_manifest.json`。技能图标的TextureRect先设为忽略原图最小尺寸，再分配atlas，防止图集撑大HUD；实际截图已目视确认。

## 重跑

```powershell
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --headless --path 'W:\wMacSync\SynologyDrive\Godot Projects\gersang' res://tests/v2_suite.tscn
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --headless --path 'W:\wMacSync\SynologyDrive\Godot Projects\gersang' res://tests/test_runner.tscn
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --headless --editor --path 'W:\wMacSync\SynologyDrive\Godot Projects\gersang' --script res://tests/editor_formula_smoke.gd
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --path 'W:\wMacSync\SynologyDrive\Godot Projects\gersang' res://tests/v2_capture.tscn
```
