# 自動排序實測 — 2026-10-11

Godot4.7.1 / Compatibility / Windows。原生編輯器測試用獨立沙盒，遊戲测试隔離存檔。
非headless像素測試／截圖使用實際GPU（RTX PRO6000 Blackwell）。

| 檢查 | 已執行結果 |
|---|---|
| depth_sorting_suite headless |71/71：11圖原場景bytes、位置／basis／Offset／owner、導航／入口／出生不變；分類、鏡像腳底、分件合法性 |
| depth_sorting_suite 實際渲染 |75/75：另有4個真正像素斷言，巢狀樹／人物前後交换、貼地不蓋人物、明確前景覆蓋 |
| 原生Editor排序／校準／分件 |24/24：中文四選項含真正「沿用」、Undo／Redo、共用Resource影響兩件、分件複製獨立ID、保存重開 |
| 非headless MOVE |40/40：30/120 FPS，世界／戰鬥同速、插值與鏡頭同pose、無反向抖動 |
| 完整統一 --all |122 passed /11 failed（頂層案例／子套件，不是所有子斷言總和），仍非全綠 |

完整回歸通過：實際RTS／技能、選兵、縮放、冰牆AI24、裝備、角色面板、
戰鬥操作／勝利流程、爆雷、BGM、同期語音、地圖投影、多批敵人、補人口、
原生戰場254及上輪編輯工作流。新排序套件加入統一入口，可單獨重跑。

未過的11項是保留的目前布局／旧fixture：河灣仍假設22隊、回圖人口；
forest孔洞超框／活動域超追擊域、well_1活動域超追擊域；test_runner旧固定
部署／傷害／不可達點；方向fixture找旧elite；native_tiles、人本製圖、
河灣豐富化、怪物分佈與戰場對位的历史內容比較。沒有減怪、恢復旧格子或
放寬導航檢查以過測試。詳見all.log，不把已有驗證狀態改為全綠。

所有本輪證據：artifacts/depth-sorting-2026-10-11/。
tests-final.log／headless-results.json、render-final.log／render-results.json，
editor-parts-final.log為Editor24最終結果，movement-render.log及all.log。
原檔before/與before-hashes.json；129個preset分類記錄在classification.json。
本輪分類只附加排序欄位，11張原圖場景file完全未寫；新增分件範本另存。

圖片world-maple-{behind,front}、world-ground-cover、cave-{behind,front}為實際
渲染測試pose，不是可達路線走訪的宣稱，也不是所有混合大圖都已分件的證明。
畫面上仍有其他物件正常遮擋人物；可見性與通行遮罩是兩回事。

初次失敗：信號計數fixture捕获int副本、SubViewport誤用own_world_2d、
Inspector重建後保留了舊控件引用，以及重開上輪同名沙盒造成Undo前值污染。
均保留旧log，修正後以最終log為準。OptionButton的-1是自動ID，不能當inherit；
已改為index-1映射，新增真實沿用選項斷言，不只數item_count。

分件Editor擴展曾因Editor MainLoop不自動建立WorldCatalog導致town_exit目的地
未登錄；測試先Initialize真實目錄後通過24/24，沒有略過目的地或導航檢查。

Editor API實際操作驗證不等於人工鼠標試用。物理鼠標／Artist最終走訪仍unverified。
