# SpriteSheet集中審視與修正 — 2026-10-13

## 原因與修正

| 現象 | 確認原因 | 本輪處理 |
|---|---|---|
| 連續轉向像腳不動 | 切換walk_方向會重置frame/progress；轉向密集時反覆停在前段 | DirectionalAnimation保存加權動作相位，所有世界怪隊與UnitView共用 |
| 出招只閃一下／未完整播放 | 舊普攻3FPS與約0.28秒前搖不配合；施法3FPS再乘0.5，短／立即施法的視覺僅0.25秒 | 原生Clip配置出招節奏；呈現事件明確重播，非循環動畫可收尾，移動立即打斷 |
| 移動與畫向不同 | 來源列並非一律E、SE、S、SW、W、NW、N、NE，銅人有正面／背面列交換，部分攻擊又不同 | 逐圖Layout映射／鏡像；Clip可獨立覆蓋，不翻轉邏輯父節點 |
| 人物切缺或夾碎片 | 9種角色沒有明確Layout；其他數張等分邊界切到本體或鄰格 | 補9份Layout，依GPU證據修7份已有裁切，保留原PNG與UID |
| 改鏡像後預覽不更新 | 原signature缺mirrored_directions | 完整signature及共用動作方向查詢 |

採用Godot原生[set_frame_and_progress及animation_finished規則](https://docs.godotengine.org/en/stable/classes/class_animatedsprite2d.html)。AnimatedSprite2D沒有AnimationPlayer.advance方法；沒有把技能示例中的advance(0)直接套到錯誤Node類別。

## 範圍與保護

開始時29張動作原圖全部檢視；26張在用、3張舊版（kohime.png、earth_claw.png、copper_monk-v1.png）未替換正式引用。26套使用原生Clip；同圖敵人／傭兵／召喚仍共享Layout。34個既有PNG（含立繪）雜湊均不變。

使用者確認同期死亡階段與7種新怪正在另一工作製作；沒有覆寫其功能／圖集。圖集回歸明確凍結本輪26個來源，不將尚未整改的新來源冒充已審視。

補Layout：guard、gunner、mage、healer、supplier、controller、archer、boss、spirit。

追加已存在的裁切修正：teppo、earth_claw_v2、copper_monk_v2、ninja、kohime_v2、shaolin_guardian、millennium_lord。merchant、elite、beast與wolf／worm已有特別裁切保持原樣；所有兵種數值／技能配表／地圖／通行／存檔不變。

備份在 `artifacts/sprite-motion-2026-10-13/before/`，包含原生資料與程式，以及原圖雜湊清單；設定變更見applied.json與完整336格crop-final-diff.json，逐張GPU圖在gallery。一次性工具不會在運行時重建資料。

## 已批准補畫與正式接入

| 共用圖集 | PNG | 原生Layout |
|---|---|---|
| 鐵炮手／敵方／同伴召喚 | features/units/art/teppo-motion-v2.png | features/units/data/layouts/teppo_motion_v2_layout.tres |
| 銅人／宗師／增援 | features/units/art/copper_monk-motion-v3.png | features/units/data/layouts/copper_monk_motion_v3_layout.tres |
| 千年鳥 | features/units/art/millennium_bird-motion-v3.png | features/units/data/layouts/millennium_bird_motion_v3_layout.tres |

三款保留原造型、加入四幅獨立行走／拍翼姿勢；不以idle重複幀冒充新畫。8份UnitDefinition僅換美術引用及外觀比例，能力／技能／持久ID不改。舊PNG及Layout保留。生成使用內建image_gen，提示、來源及被淘汰鳥版見[sprite_motion_image_prompts](sprite_motion_image_prompts.md)。

千年鳥v3實際7來源列／8欄，Output仍8方向，原生不規則裁切可引用正確北向出招區域。銅人北／西北施法的正面姿勢改用同方向乾淨背向出招Rect；不新增傷害。Cast的Instant Start Frame=1讓零前搖直接顯示出招，正常有前搖從0開始。

已更新無BGM Web引用白名單（915項）；本輪沒有匯出或部署Web包。

## 驗證

- 最終圖集專項：headless 4191／0；GPU 4217／0，26張逐張截圖。包括五動作×八方向×實際引用幀、接地錨點、連續轉向30／120FPS、真正WorldPartyView、TacticalUnit出招事件、四幅新畫互異、重複攻擊、立即施法起始／收尾及移動打斷。
- 原生內容：440／0；新兵種／技能實戰：108／0。僅替換與本次可變幀決策衝突的固定兩幀斷言，原有兩種行走圖不同像素檢查保留。
- 隔離原生Editor：14／0，預覽、Undo／Redo、保存重開通過；不是所有人工鼠標操作驗收。
- GPU MOVE：40／0，30／120FPS速度一致，無垂直左右繞行／倒退；不改動MovementFeel或路徑。
- 前半輪全套--all：131通過／11失敗，與前輪失敗清單一致，完整報告保存full-results.json。包括現行地圖人口／歷史场景快照差異、舊world_direction回歸找不到elite代表fixture等；沒有改地圖來迎合舊快照。補畫及同期新增內容後另用獨立副本執行完整回歸；因部分舊測試依賴artifacts的歷史fixture／未自行建立輸出資料夾，初次副本結果另列測試環境失敗，不能稱為正式來源回歸，也不冒充全綠。
- 最終副本原始全套：128通過／15失敗，完整原始報告為final-isolated-all-results.json。4項是副本準備問題：world_scenery缺歷史Scene、3種語音suite未自建結果資料夾。補齊後分別1244／0、502／0、250／0、33／0，重跑日誌保留；沒有改寫原始全套報告，餘下11項為歷史人口／場景／fixture差異。UI與地圖不為迎合測試被回退。
- AI索引Verify最終37主題／97文件／0問題；34個原PNG雜湊未變。沒有修改使用者正式保存。

## 尚存美術限制

除三款補畫外，多數原圖只有兩個行走姿勢，一個待機姿勢；本輪加入經過姿勢的播放編排，不等於所有角色都有四幅新圖。長袍腿部動作幅度小、近似方向與手持武器偏角，仍受原画內容限制。待機單幀是静止待機，不假裝已有呼吸動畫。

千年鳥正南、右上待機／飛行與北向施法已補畫並逐次校準；鏡像共用左右視角仍會翻轉不對稱裝飾，是2D鏡像的限制，不翻轉邏輯方向。不是每一幅原圖都已重繪，也不是對所有玩家鼠標操作／極端施法性能的完整人工驗收。
