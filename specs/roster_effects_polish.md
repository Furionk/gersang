# D32 倉庫存取及戰鬥特效

使用者2026-10-11要求倉庫單獨存入／取出，改善火徑、雷擊及魔爪，火龍全戰場射程。本契約覆蓋D31固定七人，其他D31保存／ID／立即按鍵規則繼續適用。

- Active為1–7名（主角party_0固定），Reserve最多100名。deposit移走完整紀錄，withdraw將指定完整候補加入尾席，exchange仍可原席交換。禁止丟失角色、複製ID、滿員取出、主角入庫。席位可重新編號，Persistent ID不變；選中入庫兵時選回主角。schema v1仍需原七人；v2允許可變人數，不以空物件填充席位。
- UI提供三種按鈕及鎖定狀態；WorldSession先保存完整候選及同步player_party再發布。正式遭遇快照、練習戰場、世界列、角色頁及結算依實際Active數量；Reserve不分經驗。存取只允許探索且無控制权。
- 火徑8幀原創位圖，固定在每個平面火點，依出生時間播放／消退，重用Sprite節點；同一施放重疊火點只傷一次、3秒火點期限、15秒自身效果、CD0不變。敵方空Sprite Path沿用同一新素材。
- 雷擊8幀位圖取代簡單畫線，地面位置由Sprite Grounded／Foot Ratio校準。只替換呈現；一次立即傷害，不能把動畫8幀當8次傷害。
- 火龍SkillDefinition.battlefield_range可編輯；方向預覽、飛行距離依GroundMap.cells的Scene對角線計算，持續時間=飛行距離/speed＋trail_length/speed。釋放複製Effect Data再改距離，不改共享Resource；R後每次左鍵確認。傷害寬度、tick及公式不變。
- 魔爪新增原創48格八方向圖集，UnitDefinition.visual_scale=1.8；外觀腳底錨點固定，不變碰撞／導航。原生Layout的attack_columns及attack_fps支持抬爪→刺地→收爪；其他圖集預設維持原動畫。自主尋敵、不可控制、智慧釋放快照照舊。每次普攻造成一次地面AoE，使用地樁突襲原素材短暫尖刺爆發，視覺無額外傷害。
- 原源圖及Artist地圖保留；本輪生成素材保存在專案並記錄prompt。不得用一次性工具重建地圖。

測試：roster_effects_polish_suite headless／GPU，mercenary_storage_suite、new_units_suite、--all、實際MOVE。證據 artifacts/roster-effects-polish-2026-10-11/。物理滑鼠人工驗收另列。
