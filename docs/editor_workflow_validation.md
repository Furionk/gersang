# 編輯工作流實測 — 2026-10-11

Godot4.7.1，Windows／Compatibility。測試使用隔離資料／副本，不覆寫正式進度。

| 證據 | 結果 |
|---|---|
| editor_workflow_core_suite |14/14：資源鍵刷新、明確覆蓋與單項還原、真正技能輸入、衝突、轉場遮罩／鏡頭 |
| editor_workflow_core_suite（實際渲染） |15/15，另驗證載入期間確有上一個完成畫面的Texture |
| editor_workflow_data_suite |74/74：32兵種路徑、進度／ID／收據保留、11圖像素／腳底／導航／單Sprite幀切分及容量54；最後重跑無引擎錯誤 |
| dynamic_reinforcement_suite |18/18：每秒重抽、物種0/1、抵達才加入、!未必加入、世界繼續、凍結／取消／牆 |
| multi_party_suite |66/66：多批RTS、結算／保存重試／取消／回圖、五戰場可達出生 |
| 原生編輯器沙盒 |19/19：中文鍵選擇器、Undo/Redo、單Sprite複製ID、保存重開與build |
| 非headless移動 |40/40：真實Sprite／鏡頭，同步30／120FPS速度及無反向抖動 |
| 技能／選兵／養成 |65/65、14/14、142/142；斷言對應實際配置技能聯集，不固定假設鐵衛只有一招 |
| 入口hover／合法接近 |1243/1243，終點在可達觸發半徑，不要求站在中心；不瞬移 |
| 新怪區／人口同步 |20/20，正式存檔只讀副本，除已知Resource路徑遷移外身份／進度／收據相同 |
| 文檔索引 |22/22；24topics、69分類文件，default_key有限讀取直達工作流 |

路徑 `artifacts/editor-workflow-2026-10-11/`。core.log、data-final.log、
reinforcement.log、multi.log 是上述證據；editor-final.log、core-render.log、
movement-render.log及results.json為最終專項證據。初次失敗日誌不算通過。

## 完整回歸未全綠

`all-final.log` 完整執行了統一 --all：119通過、13未通過（頂層案例／子套件）。
不可把這個數字當作所有子測試總和。包含：

- T02/T13仍假設河灣22隊；現有farm增至12隊、其他區域保留，不能為測試減怪。
- 河灣forest孔洞超出外框／活動域超出追擊域；古井一樓cave_hunt活動域超出追擊域。
  這些作者幾何本輪未改；運行導航仍用合法域交集，試玩配置檢查繼續報錯。
- test_runner的旧入場／固定傷害／不可達位置fixture；方向測試找不到舊elite代表物。
- native_tilemap、human_authoring、river_enrichment、monster_layout仍比較較早人口／
  範圍／圖層快照；battlefield_alignment報7個歷史布局差異，但原生格中心／角點
  與實際physics查詢都通過。保留現在meadow／lake藝術布局，未恢復舊格子。
- 同期unit_voice工作於最後全回歸期間更改／增加語音清單；資源未全存在或匯入。
  只做正常import，不改它的配置／音檔，也不把它當成這輪完成的交付。
- 全回歸中的data套件74斷言全過，但新增「無可選hover樣式」fixture揭露了
  get_meta(null)引擎錯誤。已改為has_meta保護，再跑data-final.log：74/74且無ERROR。
  保留完整回歸原日誌，不重寫為全綠。

入口與舊快照測試改用半徑可達／幾何段驗證及已知路徑遷移；歷史備份本身
不改，tests/world/legacy_scene_fixture.gd只產生引用換路徑的隔離副本。
後續若要修作者範圍，先在原生Polygon檢查／由作者確認布局，不能放寬驗證取代修圖。

已按批准移動32個資料檔，更新23個引用檔；1715個純裝飾wrapper在11圖扁平化。
原圖／引用備份在 scenery-before、unit-move/before及references。
千年湖Position_3合法54格、原Capacity60，阻擋入場；只降為54，保留位置／格子。

原生編輯器以Editor API在沙盒驗證Inspector鍵選擇器、Undo/Redo、純Sprite
新增／複製／ID／保存重開及真正build callback。這不是人工滑鼠操作驗收。
新地圖藝術效果、真實玩家操作與全專案舊fixture差異須與自動測試分開報告。

以 `tools/record_editor_workflow.ps1` 重建結果及來源雜湊；它只写artifact，
不更新遊戲資料／存檔，不自动把未通過的檔案標成UNCHANGED_VALIDATED。
原始設計文案SHA256仍為67FF7A813F874197F993637AE3B901A6FED2E455DD7455BD67DF60D8220FF6FD。
