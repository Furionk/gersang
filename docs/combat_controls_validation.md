# 戰鬥操作 V3 驗證 — 2026-10-09

Godot 4.7.1 stable / Compatibility，Windows。使用專案真實GameDirector／HUD／單位／技能；所有測試隔離正式進度。

## 已執行

- `tests/combat_ux_suite.tscn` headless：60項、0失敗。涵蓋R準備／左鍵釋放／重新確認，SELF與E確認、Ctrl及按住不重播、無圈的單位指向、合法／非法點選、目標閃爍、每單位自動施法、多選混合開关、獨立深複製技能資源及缺魔開關。
- 同一場景非headless：61項、0失敗。額外檢查Windows backend的Input.mouse_mode確為CONFINED可見模式；實際輸入經Godot視窗縮放與GUI命中路徑。證據 `artifacts/world/combat-ux-render-results.json` / `combat-ux-render-delivery.log`。
- `tests/run_all.gd -- --all`：111項主入口、0失敗，包含十個子场景、既有技能、選兵、GUI、角色養成／物品／裝備、冰牆AI以及MOVE資料與真實場景回歸。這是主入口斷言數，不是把全部子場景內部項目混成111。證據 `artifacts/world/combat-ux-all-delivery.log` / `results.json`。
- 非headless `tests/world/movement_regression.tscn`：40項、0失敗，30／120FPS的真實角色／鏡頭及速度检查。導航、派生速度、插值沒有修改，D09保護保留。證據 `combat-ux-world-movement_regression-final.log`。
- 引擎匯入：`combat-ux-import-final.log`，exit0，無script error。

自動技能驗證：射程內受傷／缺魔、滿值不耗、遠距不追、補魔不自補、攻擊暫停後恢復原目標；AI選人間隔不是冷卻。冷卻從所有已配置技能資源取0，未將持續技能duration/tick或普攻interval歸零。

技能確認閃爍只影響目標sprite alpha，0.32秒後回到1；其他單位與共有圖集不變。多選技能按ID合併，但每個施法者使用自己真正擁有的Resource，不以第一位的資源指標替代其他深複製資源。

## 渲染與界限

已查看實際Godot畫面：`combat-ux-unit-target-aim.png`、`combat-ux-enemy-confirmation.png`、`combat-ux-autocast.png`。單位指向沒有範圍圈，所選技能與單位資訊一致，自動狀態在技能欄可見。

這是原生引擎GUI注入與渲染，不是人工鼠鍵驗收。**實體鼠標拖曳到視窗外的檢查尚未人工执行**；已驗證F1、echo拒絕、Windows backend模式、失焦／回焦、選單／轉場釋放及F1保留鍵。使用內嵌Game面板遇到平台限制時請另外用獨立遊戲視窗試玩。

角色畫面／世界作者工具原有人工驗收閘門不因本次測試而改標為已驗。
