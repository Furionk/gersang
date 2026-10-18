# 文檔與專案結構 Audit — 2026-10-09

範圍：本Godot專案的文檔位置、權威資料、查閱入口及重整風險；不是全面性能、記憶體、安全或插件GUI驗收。使用者選定 **先Audit＋分類索引，不搬檔**。沒有初始化Git、刪除文件、移動Resource／Scene／腳本，也没有對正式user://存檔操作。

## 基線證據（新增索引前）

`rg --files --hidden`排除.godot、artifacts、.import/.uid的盤點：28份Markdown／JSON記錄（根2、specs9、docs15、tests2）；28個根日誌、23個tests日誌、38張tests圖片在生成證據區之外。artifacts已有130文件及.gdignore。12個UnitDefinition、11個SkillDefinition、44個ItemDefinition；9個feature資料夾；2個啟用Editor插件。

根README約11.9KB，來源世界文案約49.7KB；GameDirector835行、GameHud606行。這些是基線尺寸，不是聲稱已完成所有模組質量認證。原始清單可由 `project_context.ps1 -Inventory`及本次提交的索引角色分類追溯；新增索引使文檔總數增加。

## Findings

| 優先 | 發現／具體依據 | 對AI迭代的影響 | 本輪處理 |
|---|---|---|---|
| 高 | README堆疊多階段舊操作；combat_v2.md仍有舊連射／即時自身技／四欄疊窗說明 | 局部搜尋容易撿到失效要求 | 分類為historical，預設只讀V3／角色現行契約 |
| 高 | feature manifest偏世界執行與驗證，沒有兵種／技能資料／成長／插件自然語言入口 | 為改兵種從協調器左找右找 | 18主題路由與內容entity定位，資料權威／方法分離 |
| 高 | WorldCatalog同時有fallback，作者scene啟動時覆蓋；怪隊配置可藏在scene子資源 | 改錯來源，變更無效或覆蓋作者內容 | world索引明確以.tscn作者節點為準 |
| 高 | PartyProgress／WorldSession用res://tests/與res://tools/前綴隔離存檔 | 只為美觀搬測試可能接觸正式存檔 | 保留全部現有paths；未來tests按feature新增子目錄 |
| 中 | logs／圖片／舊結果散落根和tests，可被搜索及Godot導入混入 | token／導入／版本混淆噪音 | 預設排除，保留原位，列出將來迁移清單 |
| 中 | 原生.tres、來源items52 JSON與review CSV角色不同 | 不小心生成工具覆寫已手改平衡資料 | authority指出原生Resource，export只供審閱 |
| 中 | 两個Editor插件只有world在原feature索引顯眼；工具的寫入副作用不一 | 找公式功能費時，誤跑builder | tools／plugins入口与風險表 |
| 中 | 巨型協調器／HUD與舊報告各自帶多機制 | 每次全文重讀，無法辨認最新證據 | 路由方法名稱、最多3份READ_FIRST、預設12檔預算；狀態／來源不冒充驗收 |
| 低 | 大部分執行檔已按feature組織，shared schemas與shared art有清楚用途 | 大搬家沒有足夠收益 | 保留原架構，先改資訊架構 |

## 建議擺放與未執行搬移清單

- 既有現行契約 →將來 `specs/contracts/`；保留原始sources及decisions。要改manifest、索引、AGENTS、文內鏈接及讀取工具。
- 既有操作／製圖指南 → `docs/guides/`；當次報告 → `docs/validation/`；真正失效文案 → `docs/history/`。不能將歷史中仍唯一存在的數值說明直接刪除。
- 根／tests生成logs、結果及截圖 → `artifacts/history/<milestone>/`；要先確認引用，更新capture/test輸出與文檔鏈接，保留原檔雜湊／provenance。
- 新兵種／技能／世界設計意圖 → `docs/design/`，只指向原生數值；插件／工具工作流 → `docs/tools/`，架構 → `docs/architecture/`，日期Audit → `docs/audits/`。
- 程式／資源／plugins此輪不建議大移位；未來有明確責任重構時再用Godot資源引用與UID驗證，不依外殼批量改名。

本次新增的六個入口／導航文檔採上述新位置；原有28份記錄與生成物保留原位。**先解決找得到、分得清、驗得出，不以資料夾數量當整理成功。**

## 固定開發節奏

### 本輪實測

新增入口後35份文檔／JSON記錄全有分類，18主題路由 `project_context.ps1 -Verify` 0問題。`tests/context_routes_test.ps1` 16項通過：中文／內容名稱定位、3份READ_FIRST與12檔預算、歧義候選、插件／scene權威、歷史分類、未知topic、路徑逃逸及斷開related拒絕；證據 `artifacts/world/context-index-results.json`。例如「地震術」只給該技能.tres，packet含6個相關schema／程式／資料檔，而非讀全部技能及整個協調器。沒有以此宣稱實測了整體開發速度提升百分比。

F1大地圖擴展：headless68項、非headless69項通過（來源 `world-f1-first.log`／`world-f1-combat_ux_suite-render.log`及combat-ux JSON）；完整入口111項、0失敗，移動實際渲染40項通過，匯入exit0。確認世界F1不改位置、世界→戰鬥→世界保留偏好、倒數維持限制、載入／結果暫釋放與退出清除。實體鼠標拖曳出界仍不是本次人工驗收。生成證據在artifacts/world；沒有搬動原位文件。

1. 根AGENTS→主題查閱packet；只讀READ_FIRST與要改的權威資料／方法。
2. 若不明確，工具列候選；接口變更、缺檔、失敗才擴查related。不要預設讀所有dependencies。
3. 修改後跑相关場景，記錄版本及實測；涉及MOVE／呈現照原保護閘門。
4. 新增／改名文檔須分類，`project_context.ps1 -Verify`不能有Missing／Unclassified；新機制加topic，不造第二份數值庫。
5. 保留未完項目與人工驗收，不把舊JSON、雜湊或空按鈕當passed。

依據：[Godot組織建議](https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html)與專案實際catalog、author scene覆蓋、autoload隔離條件；沒有宣稱執行了不相關的signal／ObjectDB掃描器。
