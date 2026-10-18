# 資源結構與AI檢索審視 — 2026-10-13

範圍為分類、檢索入口與生成物；不是刪除未引用美術、重平衡、存檔遷移或重新部署。

## 實際盤點

- 根log28；tests根log23、PNG38、PNG.import38、生成結果JSON2。approved_monster_layouts/approved_portal_edits兩份JSON在tests/world，是測試fixture，不是應清掉的結果。
- artifacts原有3666檔、約1102MiB，含證據、備份、Web包及基線專案副本；已有.gdignore。這批占磁碟不代表被打包或應全部刪掉。
- features653檔約95.66MiB、art754檔約125.84MiB；保持feature-specific art和shared art分工。這是檔案體積，不是匯出體積／VRAM估算。
- export_templates、feature_profiles、script_templates、text_editor_themes各0檔。已在本機APPDATA/Godot找到4.7.1.stable模板，故不能把專案根空目錄說成匯出缺依賴。四目錄的精確建立原因未證明；本輪保留。
- .godot快取不納入來源體積；正式Resource／Scene／UID／import及user://未改。

## 已完成的低風險改善

1. 加入資源分類政策及read-only project_inventory工具，區分source／fixture／evidence／cache／optional tooling。
2. .ignore排除預設rg的.godot、artifacts、歷史README及log／已知截圖；.gitignore補齊生成證據規則。忽略不等於刪除；沒有初始化Git。
3. 根README由疊加的過時操作改為短的現行入口。舊README原文保留docs/history/readme_before_2026_10_13.md，其中相對路徑按原專案根解讀，不作現行玩法權威。
4. AGENTS增加精準讀取界線；native文件是權威，baseline-project副本／舊結果不是修改來源。
5. 新分類與審視加入context_map；索引仍只導航，不複製數值。以前「只有18topics」的描述已更新。

## 已授權完成的實體歸檔

使用者明確批准後，91個主要生成檔（28+23+38+2）及38個截圖sidecar，共129檔已移到artifacts/history/2026-10-13。保留原文、SHA256、原位置與manifest回復清單，逐檔核對；沒有遞迴刪除。

8份舊capture／suite的生成輸出改由TestArtifacts送到artifacts/tests/<suite>；測試入口和兩份approved fixture保持原路徑。root/tests舊結果分類與歷史報告指向保留的歸檔，避免改成讀最新結果冒充舊實測。原README原文內相對路徑按原根位置與manifest解讀。

可逆回復命令：`./tools/archive_generated.ps1 -Mode Restore -Run 2026-10-13`；若原位置已有新檔則拒絕覆寫，需要先人工處理。工具預設Plan，不移檔；Apply要明確指定。

沒有按「未引用」自動刪PNG／聲音：動態載入、模板fallback與作者備選素材未必能靠簡單引用掃描判定。正式資料路徑要遷移時需要Godot引用／UID／保存策略另案驗證。

## 本輪驗證

- Godot 4.7.1原生匯入完成，檢查日誌無ERROR／SCRIPT ERROR。
- 戰鬥V2 headless專項65通過／0失敗；視窗縮放GPU專項96通過／0失敗。新JSON及PNG已實際寫到artifacts/tests/v2及resize，沒有再生成到tests根目錄。
- AI路由回歸22通過／0失敗；索引Verify為35主題、90文件、0問題。結構Verify為0散落生成候選、2份保留fixture、0問題。
- 歸檔129檔逐一SHA256相符；預設rg檢索不包含artifacts、.godot或log，正式project.godot及fixture仍可找到。
- 這輪沒有重跑完整玩法回歸，也沒有做Web重新匯出／部署；之前完整回歸的11項既有失敗不因本輪專項通過而視作已修正。GPU專項是引擎注入輸入，不是使用者真人操作驗收。

本輪引擎驗證日誌保存在 `artifacts/structure/2026-10-13/`。

現行政策見[resource_policy](../architecture/resource_policy.md)，模組責任見[project_map](../architecture/project_map.md)。採用[Godot feature/scene附近組織及gdignore建議](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)，不是按檔案類型把所有來源塞成全域scripts/sprites。
