# 受保護的移動手感契約（D09）

來源：使用者要求「大世界垂直移動卡頓，與戰鬥不同；修正並確保不會隨意被改掉」。本文件優先於來源設計文案 §06 的首版四向／禁止平滑預設。不修改原始來源快照。

## 不得回退的行為

- MOVE-01/02/04/05：等角畫面的垂直／水平／斜向點擊，在合法空地必須走直線；不能被格中心吸附、四向階梯或 L 形繞行改變。邏輯距離依舊在正交 XY 計算，不能改成畫面距離。
- MOVE-03/08：世界主角使用與戰鬥相同的 resolved_stats.speed、movement_multiplier；禁止重新硬編碼 180 或獨立推導敏捷。共用 MovementFeel 算術，不改戰鬥數值來遷就世界。
- MOVE-06：直線捷徑、格路徑平滑每一段必須經完整 capsule、半徑、孔洞、障礙及模式域檢查。八向 AStar 禁止穿阻擋角；尋路仍不是 teleport，也不能允許 partial path。
- MOVE-07：轉向與戰鬥共用參數；完全反向不能因 normalize(lerp) 固定在舊方向。面朝更新只影響呈現，不把位置轉出合法域。
- MOVE-09/10/14/15：模擬固定 tick；顯示插值是獨立 WorldVisualPose。角色和跟隨鏡頭讀同一個 pose。傳送／換圖重置插值；不能把插值位置寫進世界資料、碰撞、遭遇或存檔。
- MOVE-11/12/17/18：呈現 FPS 不能改變權威移動速度；鏡頭使用時間一致的指數響應。30/120 FPS 實際場景保持相同速度，連續垂直呈現不得左右繞行／倒退。
- MOVE-13/16：跨路點保留未消耗距離；世界與戰鬥動畫節奏使用相同派生速度比例。

## 修改閘門

修其他功能不能移除或放寬上述條件。確有設計需求改手感時，先指出具體契約差異，取得使用者新決策並更新 ADR 和測試；不能只改測試門檻讓回退通過。

任何導航、移速、轉向、角色呈現或鏡頭改動都必須跑 `tests/run_all.gd`。預設入口已包含 33 項 MOVE 資料檢查；`--all` 再跑實際角色／鏡頭與 30/120 FPS 場景。畫面修改另執行非 headless 的 `tests/world/movement_regression.tscn`，引擎錯誤與非零退出不能忽略。

```powershell
./tools/spec_context.ps1 -Feature movement
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --headless --path . --script res://tests/run_all.gd -- --all
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --path . res://tests/world/movement_regression.tscn
```
