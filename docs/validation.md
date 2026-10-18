# 第一階段驗證記錄

引擎：Godot 4.7.1.stable.official.a13da4feb。日期：2026-10-07。

## 功能驗收

當時`tests/test_runner.tscn`的 **72 項檢查全部通過，0 失敗**。這是歷史實測，不代表現版全綠；原始逐項結果已保留於 `artifacts/history/2026-10-13/test_results/acceptance-results.json`，結束標記為：

```text
GERSANG_ACCEPTANCE_PASS | passed=72 failed=0
```

覆蓋實際引擎的導航與 GUI 路由，以及以下場景：
- 行旅點擊移動、障礙繞行、3 秒遭遇倒數與返回原位置。
- 單選、框選、Shift 加選／取消、編隊保存與召回。
- 命令覆蓋／追加、駐守不追擊、停止後延遲索敵、雙方自動索敵。
- 施法距離、MP 扣除時點、取消、補魔、治療、控制、投射物完成。
- 按住技能鍵連射、放開停止、Ctrl 預約與 E 跳過不可用兵。
- 原生 viewport GUI 點擊不發出地面命令、按鍵保存和保留鍵位檢查。
- 不可達目的地提示、不暫停的戰鬥選單、勝利／敗北／撤退及重進場。
- 草地、山道與洞窟的可通行出生點；12 對 60 壓力場景亦避免出生於障礙內。
- 多次場景重建後單位／投射物清理，orphan nodes 維持 0。

測試對特定戰鬥條件使用固定編隊、受控位置與生命／法力 fixtures，以隔離驗證各行為；它不是對原作數值的驗證。GUI 使用 Godot viewport 原生事件路由，並另以實際 GPU 渲染檢查畫面。

## 本次時間與壓力測量

| 項目 | 本次結果 |
| --- | --- |
| 200 邏輯單位移動，畫面上限 30 FPS | 1.467 秒 |
| 同一路徑，畫面上限 120 FPS | 1.424 秒 |
| 2.7 秒受控攻擊窗口 | 兩種畫面上限皆為 2 次攻擊 |
| 壓力場景 | 12 名友軍、60 名敵人，72 出生點均可導航 |
| 採樣時移動／追擊／攻擊／施法中的單位 | 16 |
| Headless 幀耗時 P95 | 9.912 ms |
| 採樣物理處理時間 | 4.032 ms |
| 受測命令最長等待時間 | 33.184 ms |
| 初始／結束 orphan nodes | 0 / 0 |
| 驗收總耗時 | 37.979 秒 |

這些是本機 headless 執行的 CPU／排程採樣，且包含 30 FPS 上限下的輸入測試；不是 GPU benchmark，也不是原作網路延遲或其他電腦的效能保證。原作移速、前搖、施法節奏與數值仍需玩家試玩或實機錄影校準。

## 實際畫面 QA

`tests/visual_capture.tscn` 使用 Compatibility renderer、NVIDIA RTX PRO 6000 Blackwell Workstation Edition 實際渲染，成功輸出 `GERSANG_VISUAL_CAPTURE_OK`：

- `world-preview.png`：行旅、村落物件、妖獸與圓形小地圖。
- `battle-preview.png`：七人編隊、HP／MP、選取圈、底部命令 Dock。
- `settings-preview.png`：手感滑桿與鍵位設定。
- `terrain-1-preview.png`、`terrain-2-preview.png`：山道與洞窟。
- `skills-preview.png`：爆雷與雷擊的實際戰鬥特效。
- `animation-preview.png`：鐵衛在 Godot 的八方向／五種動作驗證畫面。

目視檢查確認中文可讀、角色及地物腳底排序、三種地貌有區別，訊息列在捲動區域內顯示。HP／MP 位置依各圖集待機的透明邊界計算。動畫仍是初版姿勢圖集，未宣稱為原作完整逐幀動畫。

## 重跑

```powershell
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --headless --path 'W:\wMacSync\SynologyDrive\Godot Projects\gersang' res://tests/test_runner.tscn
& 'R:\App\Godot_v4.7.1-stable_win64.exe' --path 'W:\wMacSync\SynologyDrive\Godot Projects\gersang' res://tests/visual_capture.tscn
```

功能測試只把測試鍵位寫入獨立的 `user://gersang_acceptance_settings.cfg`，不覆蓋玩家的 `combat_feel.cfg`。圖片與 JSON 是驗證產物，重跑會更新它們。
