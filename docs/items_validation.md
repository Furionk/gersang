# 物品 v1 驗證

## 結果

Godot 4.7.1。物品 suite **144 通過、0失敗**，完整入口 **109通過、0失敗**（含各子回歸）。物品、原世界／結算／保存、既有戰鬥／技能／養成、冰牆、縮放及受保護 MOVE 檢查均已執行。

資料：30件裝備（六類各五件）、5種只有資料的食品、2種使用者指定 Debug 道具；原7個實驗品保留，因此匯出44列。35份參考 `.tres` 逐一核對名稱映射、等級、重量、區間／加成及非空原圖引用。原圖透過來源網址匯入，JPEG／GIF像素只轉PNG以供Godot使用。

實際 viewport GUI 事件測試驗證「選兵 → Debug按鈕 → 指定兵取得／直裝」，不會誤發地面命令。戰鬥臨時裝備加入所選技能欄，藥能恢復真正死亡單位的FSM／碰撞；臨時書和裝備不改永久 records。

渲染已查看1280×720及800×450 Debug面板。移動的非 headless檢查另跑 **40通過、0失敗**，仍維持直線路徑、戰鬥一致移速、角色／鏡頭插值及30/120FPS無反向抖動。

## 證據

- items-results.json、items-suite-final.log：144項。
- items-full.log、results.json：完整109項入口及所有子suite。
- items-debug-1280x720.png、items-debug-800x450.png、items-debug-consumables.png：實渲畫面。
- items-import-final.log：匯入／解析。
- items-movement-render.log：移動保護40項。
- items-review.json／csv：從原生資源輸出的審閱快照。

上述檔案在 artifacts/world，不作Godot資源匯入。測試沒有使用正式玩家保存路径，保留早期失敗記錄（其中一個Typed Array條件分支錯誤已修正）。

## 限制

暗黑火焰、滿月舞未還原，保留來源名稱而非假技能；已接的爆雷擊／一擊必殺使用本作可調規則。10天到期、完整職業限制、交易及商店不在此版。Release匯出未實際測試，只做了OS debugbuild的入口／服務防護。原參考圖不代表已獲商用授權。

正式權威是原生 `.tres`，來源JSON和匯出CSV不自動覆寫；指南見 items_debug_guide.md。整體製圖GUI／人工世界比對的原有待驗項目未因此改成完成。
