# 資源分類與AI讀取政策

正式Godot專案根以`project.godot`為準；本案為gersang，不是舊Unity AREA_PM2。本文件是分類規則，不是另一份HP／技能／地圖數值庫。

| 類型 | 位置 | AI應如何使用 |
|---|---|---|
| 正式運行資料／代碼 | common、features、art | 原生`.tres/.tscn`和所用schema是修改權威；不為美觀搬路徑 |
| 編輯器來源 | addons | 按需要看原生插件；不是遊戲執行狀態 |
| 契約與決策 | specs | 最新使用者要求／decisions優先；sources保留原文 |
| 指南／架構／當次審視 | docs | 從index進入，區分現行操作與歷史記錄 |
| 測試來源與固定fixture | tests | 保留res://tests/隔離前綴；approved_*.json是基準，不能當結果垃圾 |
| 查閱／製作／驗證工具 | tools | 先讀副作用；找資料不用執行builder |
| 生成證據、備份、測試包 | artifacts | `.gdignore`阻止Godot導入；`.ignore`排除預設rg檢索。需要舊證據時用精確路徑顯式讀取 |
| 引擎匯入快取 | .godot | 不視為來源，不搬、不提交；UID來源檔與正式`.import`不可順手清掉 |
| 工具／可選編輯器目錄 | export_templates、feature_profiles、script_templates、text_editor_themes | 此次均空且未被runtime引用，不是缺失遊戲資源；不單憑空白自動刪除 |

角色／技能專用Art保留在feature附近，共用Art保留art；Godot沒有要求所有圖片集中到一個sprites資料夾。`.uid`、正式素材`.import`、外部Resource引用與存檔definition_path具有關聯，搬正式資料需另做遷移，而非PowerShell批量改名。

## 空白工具資料夾

目前專案四個目錄同時建於2026-10-10且均空。本機正式4.7.1匯出模板可在`%APPDATA%/Godot/export_templates/4.7.1.stable`找到；專案根的空export_templates不是正在使用的模板。沒有證據可精確指認哪次工具啟動建立這四個目錄，所以不把推測寫成確定原因。

Godot編輯器資料／設定與專案資源是不同位置；要看實際位置可從Editor選單開Editor Data/Settings Folder。空的text_editor_themes只表示沒有放自訂主題，不影響遊戲美術。它們可留作可選工具目錄，本輪不刪。[官方資料路徑說明](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html)

## 長期生成物規則

新測試結果放`artifacts/tests/<suite>/`，一次性歷史歸檔放`artifacts/history/<date>/`，發佈測試包放`artifacts/<build-task>/web/`。保留log原文、hash、執行命令、引擎版本與未完成項目；不是看到FAIL就刪除。

`.gitignore`與`.ignore`不刪任何檔案；前者控制未來版本管理，後者讓預設rg只讀來源。需要生成證據請明確指定`rg --no-ignore artifacts/<task>/...`，不得把歷史副本當現在修改來源。現行來源檢索用：

```powershell
./tools/project_context.ps1 -Query '兵種'
./tools/project_context.ps1 -Topic content_authoring
./tools/project_inventory.ps1 -Json
./tools/project_inventory.ps1 -Verify
```

結構檢查不代表玩法測試通過。資料分類不得把既有11項回歸失敗藏起來，也不得改user://存檔。按[Godot組織建議](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)適配本案，不宣稱存在唯一標準資料夾樹。
