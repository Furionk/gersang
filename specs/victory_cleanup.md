# D36 敵軍全滅後可操作收尾

使用者決策 2026-10-11：敵軍全滅不立即移除技能／效果或停止兵種，稍後才結束戰鬥與增加經驗。

正式自動勝利：敵軍全滅 → 2 秒仍為 battle（單位、召喚、技能、投射物照常 tick，仍可操作，尚未發經驗）→ 原有 SettlementService 結算 → 勝利 banner 3 秒 → 自動返回／banner 期間新左擊立即返回。

收尾期間新敵軍出現會取消倒數；我方全滅仍優先敗北。撤退不能丟棄待結算胜利。收尾不延長到所有效果自然消失：兩秒後正式結束才清理。保存失敗仍 SAVE_BLOCKED，不自動回圖。明確 debug finish_battle API 保留舊手動結果 HOLD 語意；自然全滅不再重複等待另一個 HOLD。

權威：features/battle/game_director.gd 的 victory_pending/victory_elapsed；BattleResultFlow 只管 banner/return，不管獎勵。

驗證：tests/victory_cleanup_suite.tscn；正式千年湖遇怪／兩階段王／延後發獎由 millennium_ecology_suite 補充。測試使用隔離存檔，沒有正式存檔寫入。
