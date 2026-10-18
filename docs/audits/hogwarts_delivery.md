# 霍格愛茲交付驗證 2026-10-13

本輪交付原生大地城、河灣雙向入口、30隊怪、六個新種族、三階段Lv90首領、普通及血月兩張戰場、七張角色Sheet及哥德景物Atlas。背景音樂原檔與原玩家存檔未刪除或遷移；未部署Web。

## 目前已驗證

| 驗證 | 結果 |
|---|---|
| hogwarts_suite（headless） | 63通過／0失敗 |
| hogwarts_suite（真正Compatibility渲染） | 63通過／0失敗 |
| 七張48姿勢原生AtlasTexture畫廊 | 全部輸出並目視審視；修正初次裁切碎片/三頭犬方向 |
| 河灣原場景比對 | 原導航、地景變換/貼圖/Offset、舊入口與返回點無差異；只新增1入口+1返回點 |
| content_authoring_suite | 440通過／0失敗 |
| millennium_ecology_suite | 44通過／0失敗 |
| victory_cleanup_suite | 18通過／0失敗 |
| multi_party_suite | 66通過／0失敗 |
| ice_wall_ai_regression | 24通過／0失敗 |
| battlefield_scene_suite | 254通過／0失敗 |
| 實際渲染MOVE（30/120 FPS） | 40通過／0失敗 |
| 戰鬥操作／鏡頭調整後 | 69通過／0失敗 |
| 實際Editor placeholder/build邊界 | 22通過／0失敗；故意注入非法場景會輸出預期錯誤 |
| 文件檢索路由 | 37 topics / 97 documents、0 issues |

測試用隔離進度。首領完整路徑以真實WorldSession快照進戰，三階段全清後回報SettlementService；原首領30000XP只結算一次，幻影無快照獎勵ID。

世界/血月畫面與報告：`artifacts/tests/hogwarts/`。河灣修改前備份：`artifacts/hogwarts-2026-10-13/before/river_bay.tscn.txt`。

## 完整回歸與待驗收

完整 --all：132通過/11失敗（基線此前131/11，**失敗數一致不代表每個底層原因完全相同**）。基本World套件101通過/2失敗：T02/T13仍要求河灣固定22隊，與已存在的配怪修改不符；未為過測試改怪隊或放寬導航。

完整 --all在最後收據過濾與原生尺寸鏡頭邊界修正之前完成；收據修正後重跑千年湖44/0、收尾18/0、多批66/0。最終版本再跑地城63/0（headless與GPU）、戰鬥操作69/0、渲染MOVE40/0。五幻影是普通敵軍，沒有額外發明一小時召喚消失時間；以原始持久快照ID决定收據參與者，而非拿召喚標記掩蓋空ID。

其餘九個聚合失敗：test_runner、world_direction_regression、native_tilemap_suite、human_authoring_suite、river_enrichment_suite、monster_layout_suite、battlefield_alignment_suite、editor_workflow_data_suite、depth_sorting_suite。部分固定七人、舊怪隊數/域/舊場景基線；depth_sorting有超時退出。這些不是本輪專項通過的替代。

其中human_authoring舊測試逐張尋找`artifacts/workflow-2026-10-10/original-scenes/`歷史備份，新增hogwarts當然不在2026-10-10備份內，出現null來源錯誤。native_tilemap的舊身份比較也尚未列入本輪批准的新入口；本輪獨立preservation已證明所有原有河灣值不變。沒有偷偷改歷史fixture或把新地城假裝成舊場景來壓掉錯誤。

portal_approach_suite為23通過/1失敗：舊fixture必須找到WorldAuthorNode.SCENERY父節點，但D28後純景物已改為單Sprite；實際門口接近/不穿Blocker檢查及新地城往返皆通過。沒有為此重建舊節點結構。

新Scene可原生編輯；本輪渲染/資料/引擎測試不是Artist人工滑鼠編輯或完整長時間平衡驗收。初始學校迴廊為視覺構圖，採開放通行；Artist想限制牆體須畫原生Obstacles。換景拒絕不一致的Blockers，保留安全提示。

新美術是生成的初版姿勢，更多手工中間幀、怪物技能長時間平衡與真玩家十人滿編體驗仍需後續製作/試玩。未自動新增玩家兵種、物品或改原兵種數值。

Web白名單已重新產生（915個來源、無BGM）；尚未匯出、未更新網站。下一次Web匯出必須更新中文字體子集並真實瀏覽器重驗。
