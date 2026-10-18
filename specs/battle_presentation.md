# 經典戰鬥HUD與胜利回圖契約 — 2026-10-10

首幀計時保護：GameDirector 從 victory 事件的 monotonic 時間開始推進呈現倒數，不把此前 Scene 載入的 frame delta 算入。實時驗收同樣以事件起點的 Time.get_ticks_msec 量測；不得放寬2秒／3秒門檻來遮掩早回圖。

D16按使用者四張戰鬥附圖適配，沒有重繪／修改大地圖HUD或作者地形。

## 戰鬥介面

- PRES-08..11：移除戰鬥頂部整條工具列與左側探索肖像列；左上保留小編隊／工具按鈕，右上選取角色的獨立肖像、等級、HP／MP、攻防。左下菱形小地圖、底部中央黑色訊息窗、右下四命令與技能格。
- 保留現有ClassicSkin框資產、原生Control錨點、GridContainer與視窗等比例縮放。基準dock高148邏輯像素；GUI字體加大時增加垂直空間，不截字或蓋住技能／E列（PRES-15）。
- 同時選多兵保留技能聯集與11技能的可見性；6×2格適配本專案能力數量，沒有為模仿附圖的8格而丟失技能。未用格顯示空槽。
- M/S/A/H、右鍵自動支援、E順序、F1、框選／群組不變。一般技能逐次左鍵确认，暴雷I／圖示依D17即放。設定齒輪與選單按鈕位於右上角色卡下方；試驗戰場在選單，正式遭遇中不能另開試驗場。

## 勝利時序與保存

`戰鬥終局 → results/HOLD（2秒）→ 胜利卷軸/BANNER（3秒）→ RETURNING → 大地圖`

- PRES-01..03／13：終局tick結束後停止權威戰鬥，保留戰場畫面2秒；第2秒顯示「勝利」卷軸及返回倒數，顯示足3秒後自动返回。长卡顿幀不能把卷軸顯示時間吃掉。
- PRES-04/05：卷軸顯示期間新左鍵按下可立即返回；在戰場、訊息窗或小地圖上均有效。最初2秒左鍵不能跳過等待。返回意圖同步鎖定，连點不能排第二次返回。
- PRES-06/14：正式獎勵仍只由SettlementService保存整份candidate／收據再發布。保存失敗立刻顯示錯誤及重試UI，沒有自动回圖／領獎；重試同一candidate成功才返回，不能重抽怪隊或獎勵。2＋3秒是呈現時間，**不是延遲保存或另一份結算**。
- PRES-07/12：結果流程保存ticket及encounter_id；每次返回callback在排隊及執行時都檢查結果模式／ticket／遭遇ID。換圖、重試驗場或新戰鬥會取消旧流程。重复终局／迟到结果不重复發放。
- 撤退／戰敗維持原有立即結果及返回規則，沒有套用勝利自动時序。F1 session偏好維持D12，results仍釋放實際游標。
- 不改D09移動、D11技能、D14召喚／配點或D15方向。

## 所有權與查閱

- BattleResultFlow只持有呈現時鐘与通知，沒有獎勵或地圖寫入能力。
- GameDirector接終局／保存結果／有效回圖；BattleHudLayout只排版，GameHud發同一命令／顯示結果。
- VictoryScroll是原生繪圖與字型，不是從參考圖直接裁切的新asset。
- `tests/battle_presentation_suite.tscn`：時序邊界、真實5秒時鐘、原生左擊、重複／過期回呼、正式遭遇保存失敗与重試、三視窗尺寸及大字體。
- 加入 `tests/run_all.gd -- --all`，並保留非headless移動與GUI測試。報告 [battle_presentation_validation.md](../docs/battle_presentation_validation.md)。

自製世界／地城／配怪按 [artist guide](../docs/artist_guide.md)，本輪只補充操作說明，未搬檔、重建world scenes、重置進度或宣稱Editor人工Undo／保存重開閘門已通過。
