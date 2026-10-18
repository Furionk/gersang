# D40 — 集中 SpriteSheet 動作／方向修正（2026-10-13）

使用者要求檢視 features/units/art 所有待機、移動、攻擊與施法的停頓及方向錯誤。這是呈現修正，不改D09速度／轉向／導航、戰鬥命中、施法消耗、保存、兵種強度、地圖與排序。

- 檢視29張動作原圖：26張正式在用，3張舊版未接入正式兵種。保留全部PNG，不刪除舊版。
- 所有在用圖集有原生SpriteSheetLayout與五個SpriteAnimationClip；9種舊等分圖補上明確裁切。幀數／FPS／循環／時間權重依舊可變，不改為固定四幀引擎。
- Clip可選八方向列／鏡像覆蓋，留空沿用Layout。SpriteAtlas、實戰與Inspector使用同一來源；錯誤行數／列索引仍拒絕。鏡像與動作映射納入signature，避免Editor預覽滯留。
- 原生AnimatedSprite2D是播放權威；同動作轉向保存加權時間相位，不在每次改方向時歸零。新攻擊／施法由TacticalUnit的呈現事件明確重播，不用動畫發傷害或變更施法時間。
- 立即／短施法可完成原生動畫收尾；移動、受控或死亡立即打斷呈現，不阻擋任何RTS命令。animation_finished只處理非循環動畫。
- Clip的Instant Start Frame指定零前搖施法呈現起始幀；本輪cast從第1播放幀直接顯示釋放姿勢，避免連點施法只重播待機前幀。值必須在Columns範圍內，不改Skill.cast_time。
- 本輪多數行走使用已存在的兩種踏步＋原待機作經過姿勢；不是補畫出的四種新姿勢。靈體／鳥／蠕蟲／魔爪節奏獨立。原圖腿部差異小、缺少視角或不同動作武器偏角的問題不能靠metadata完全解決。
- 使用者其後批准補畫千年鳥、鐵炮手與銅人。三款新版有四幅獨立行走／拍翼圖，原圖及舊Layout保留；敵我／召喚共用新Layout，僅調外觀比例保持尺寸。千年鳥實際7來源列／8欄，映射8輸出方向，依真實PNG裁切，不能硬補第8空白列。
- 七份現有Layout的裁切修正由实际GPU畫面確認；merchant／beast／elite及已修復wolf／worm的不規則裁切保持不動。所有原圖、既有Resource UID及存檔身份保留。
- 兩份一次性整改工具預設只產計畫，明確apply且保留備份；不可在啟動／編輯器自動重切或覆寫後續Artist資料。

驗收：sprite_motion_suite（headless及GPU）、content_authoring_suite、native Inspector sandbox、new_units_suite、完整--all及非headless MOVE。舊11項失敗須繼續列明；不移動場景、不改測試fixture配怪来让旧方向测试通过。使用者確認同期死亡階段／7種新怪由另一工作新增，保留；本輪圖集來源凍結在開始時26張，新增來源不假冒已審視。
