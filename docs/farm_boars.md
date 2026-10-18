# 租霸豬：身份與數量保護

農田怪區為原生場景 `features/world/data/river_bay.tscn` 的
`MonsterRegions/farm`。純豬隊，不混入游魂／法師；圖上代表與戰鬥成員均為
`features/units/data/monsters/beast.tres`，圖集為原始 `features/units/art/beast.png`。

Inspector保留簡單編成：Monster=beast、Party Count=12、Minimum Units=6、
Maximum Units=9、Minimum Level=6、Maximum Level=12。全區共72–108隻實際豬，
大地圖每隊顯示一個代表物。四批／60敵人遭遇上限不變。

保存並重新執行後，已存檔的修訂3農田人形怪隊會被替換；其他怪隊、槽位、
地形、入口、玩家位置／能力／背包／裝備與已發獎勵不改。戰鬥中不重建，
回圖後套用。此修訂4不可被擴充其他兵種的工具覆寫。

證據：`artifacts/boar-fix-2026-10-10/results.json`（40通過／0失敗），
同目錄`world-boars.png`為實際渲染；測試使用隔離進度，不寫正式存檔。
未將仍進行中的完整敵人擴充／全回歸標作完成。
