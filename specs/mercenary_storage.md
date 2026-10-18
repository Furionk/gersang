# D31 — 正式傭兵倉庫與忍者操作

D32 最新存取規則見 roster_effects_polish.md：Active改為1–7人，提供单獨存入／取出。本頁的固定七人為D31歷史限制，保存／ID及技能規則仍有效。

使用者 2026-10-11 要求 F2 招募／替換正式兵種，預設 Lv1，補完整立繪；迷蹤步及火徑立即、四方導雷 C。取代 D30 只試兵的限制，保留原試兵功能。

- PartyProgress 擁有 7 名 active records、最多 100 名 reserves；主角 party_0 固定。UI 發命令，不直接改陣列。交換保留完整 CharacterRecord，不刪兵、不轉移裝備／經驗給新兵。
- MercenaryRoster 純驗證／候選資料：白名單 mercenaries、獨立穩定 ID、Lv1 XP0、空裝備背包，滿 HP/MP。v1 依原始七人定義遷移；v2 保存每人 definition_path＋reserve。未知版本／重複 ID／非法資源拒絕且不發布。
- WorldSession 探索且無控制權時才接受命令。完整世界候選包含同步 player_party；先 commit 成功才發布 roster／world，一次訊號，不重複存檔。失敗保留現況；本流程同步無 await。
- 世界戰力、遭遇快照、戰場初始兵種、結算、重開載入均以存檔的個別 definition_path 為準。候補不出戰、不獲該場獎勵；結算保留候補完整資料。既有收據仍防重發。
- J 迷蹤步、K 火徑按鍵／圖示直接 request self cast，下一個固定 tick 釋放，不需左鍵。保持 CD0、無前搖、echo 不重複；E 預約保留原規則。C 導雷仍需敵軍左鍵。資源預設遵循 D28 的明確玩家覆蓋優先規則。
- 三張獨立 1024×1536 原創立繪，native AtlasTexture portrait region；現有動作 SpriteSheets 不修改。更新隊伍列／角色頁頭像，單一 dossier 不新增重疊視窗。

程式入口：features/progression/mercenary_roster.gd、party_progress.gd、character_record.gd；features/world/runtime/world_session.gd、world_context.gd；features/battle/game_director.gd；features/ui/mercenary_storage_panel.gd、item_debug_panel.gd。使用指南 docs/new_units_guide.md。

驗證：tests/mercenary_storage_suite.tscn，headless 與實際 GPU；v1/v2、錯誤版本、ID、保存失敗／重試、F2 真實按鈕訊號、戰場實際單位、勝利獎勵／重複結果、鍵盤及圖示立即施放、可見 UI。統一 --all 及非 headless MOVE。證據 artifacts/mercenary-storage-2026-10-11/；人工滑鼠驗收另計。
