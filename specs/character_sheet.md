# 角色全畫面 v1 — 2026-10-09

## 使用者決策與範圍

以附圖的身體裝備配置重新整合立繪、Inventory、能力與技能。不是重畫世界 HUD；不改戰鬥操作／移動契約，不新增未有來源的裝備數值。九個裝備位置可於原生 GearItemDefinition Inspector 配置。

## 契約與測試

- SHEET-01：測試／截圖使用隔離 PartyProgress 與 WorldSession，不讀寫玩家正式存檔。
- SHEET-02：普通配點 +1；Shift＋按下加號一次分配 min(100,剩餘點數)。合法請求最多100，非法／零點不更動；只發出一次 changed。
- SHEET-03：原 WEAPON/BODY/HEAD/CHARM 0–3 不變；HANDS/BELT/FEET/RING_LEFT/RING_RIGHT 接續。舊存檔缺新欄時填空，不複製護符；配點／物品不遺失。
- SHEET-04：技能清單由兵種技能與已裝備 granted_skills 去重聯集。未接線的來源技能名稱不是已擁有技能。
- SHEET-05：介紹顯示觸發／目標、MP、冷卻、射程、效果與來源。公式用同一 DamageFormula / record.stats；每次命中或 tick，不冒充整段總傷害。敵方防禦／物抗／法抗只是可調試算，不改真實角色資料。召喚／冰牆／回復分開說明。
- SHEET-06：點世界肖像或 I 開同一個模態 dossier；全身立繪 keep-aspect，不能以戰鬥 sprite 或頭像裁圖代替。舊 standee 相容節點保持隱藏。
- SHEET-07：換兵立即換立繪及技能；技能按鈕只查看說明，不施法或移動。公式固定於技能區下方，詳細說明可捲動；大量技能的格子另可捲動。
- SHEET-08：S 能力／I 裝備互斥；按目前模式快捷鍵可關閉。角色立繪、技能與行囊不重建另一個視窗。開啟時關閉其他世界／Debug 視窗。
- SHEET-09：Shift+加號走與 +1 相同的角色配點入口；選取兵不同時不誤配主角。能力與公式立即刷新，無點可分配時按鈕停用。
- SHEET-10：行囊點擊使用／裝備，身體格點擊卸下；沿用原子容量／重量／等級檢查。空格不可卸下；不偽造手套等尚未配置物品。
- SHEET-11：1280×720 等比設計畫布適應視窗，非16:9置中而不裁角色；背景擋住世界輸入。800×450、1280×720、1920×1080、900×900、1720×720 所有欄位可操作。
- SHEET-12：背景／介面點擊不能下地面命令；X／Esc 先關角色畫面；F2互斥；遇敵倒數先關 dossier，3→2→1不得被全畫面遮住。倒數只在首次顯示時切換模態所有權；進戰再清理。戰鬥 S / I 仍是停止／技能，不能被養成 GUI 接管。

## 責任與查閱

- `features/ui/progression_panels.gd`：同一畫面、布局、選取、唯讀試算；依 GameDirector 下達配點／裝備命令。
- `features/ui/skill_description.gd`：技能聯集與文字／公式代入；不快取或修改共有資源。
- `features/progression/character_record.gd`：配點、物品、欄位恢復權威。
- `common/data/gear_item_definition.gd` / `skill_definition.gd`：原生 Inspector 資料；description 可填自訂介紹。
- `tests/character_sheet_suite.tscn`：SHEET-01..12 的資料及原生 GUI 輸入回歸；`character_sheet_capture.tscn` 另輸出真實渲染。

下一輪先執行 `tools/spec_context.ps1 -Feature character`。完整入口 `tests/run_all.gd -- --all` 仍保留全部 MOVE 與既有子測試；不能為新 GUI 改掉移動規格。
