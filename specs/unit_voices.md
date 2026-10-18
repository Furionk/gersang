# 兵種語音契約

2026-10-11 使用者確認：原創《巨商》式短句、中日韓母語、首批32種兵建立配置，先審11段試音再全量製作。

- Runtime authority: `UnitDefinition.voice_profile` → `UnitVoiceProfile.events` (本地音訊路徑)。製作台詞／聲線／參數 authority: `features/audio/data/unit_voices.json`。角色設定是此次新增，不改存檔ID或內容版本。
- 七人隊：SELECT/MOVE/ATTACK/INSPECT各3段；箭魂：SELECT/MOVE/ATTACK各3段；23種敵人及金身銅人：ENGAGE/DEATH各3段。首批237段本地OGG全部生成、引用並匯入。後續僅新增可控忍者9段，目前33份配置／246段；湖衣姬、鐵炮手與其他新敵方／召喚物依使用者要求暫不生成。缺少未來新增資產時仍安全靜音。
- 語音：商人／醫術師普通話；鐵衛韓語；火銃手／符咒師日語。使用者更正雷術師、道術師為女性並指定日語女性角色聲線，兩人24段已重製；聲線選擇不自動改写角色國籍。少林與智慧鬼怪中文，野獸／石衛等使用非語言聲效。
- SELECT只來自玩家點選、框選、全選、編隊召回及戰鬥HUD肖像；`select_ids(..., player_issued=false)`預設靜音，死亡同步、技能輪選與入場不出聲。
- MOVE/ATTACK在SelectionController.dispatch下令後申請一次；attack_move算ATTACK，排隊執行不重播，STOP/HOLD無語音。
- INSPECT在世界資料頁打開、點角色或資料頁內再次點同一角色時申請；刷新、配點、關閉、地圖移動皆不申請。select_world_slot(slot, player_issued=false)預設靜音，由真正的角色按鈕／快捷鍵傳true；世界肖像開頁流程只由開頁申請，避免一次點擊觸發兩段。角色回應短句，不朗讀數值。
- 敵人第一次到普攻射程或成功開始施法申請ENGAGE；死亡申請DEATH。每實例每事件一次，即使當時被節流也不延後重播。
- 一個非空間AudioStreamPlayer、UnitVoice獨立bus；群組按隊伍槽位→兵種ID→實例ID選一名有資產的存活玩家單位。
- 事件shuffle bag獨立於遊戲RNG，三句輪完才重抽，跨輪避免連續同句。被略過的請求不消耗抽籤。
- 使用者最新更正：每次明確SELECT／INSPECT操作都立即播放下一句，忽略全域／同事件冷卻並打斷任何上一段回應，單通道不疊音、不排隊；重點擊同一角色也必須響應。MOVE／ATTACK仍保留0.8s全域、2s同事件冷卻及攻擊優先；敵方共用2.5s節流不變。靜音、暫停、無效／死亡目標仍不播放。
- 暫停、戰鬥modal、results/loading及場景清理停止播放；世界資料頁modal容許INSPECT。GameSettings的audio section存0–1線性音量和mute，bus透過linear_to_db調整；BGM不更動。
- 遊戲端無ElevenLabs呼叫或key。製作工具僅讀環境變數，不讀Vault或其他角色clone；公開Voice Library聲線必要時加入帳戶，保存公開來源及ID。
- 使用者已於2026-10-11確認第二版並明確要求套用所有兵種，manifest的full_generation_approved已設true；全量237段完成。後續風格變更仍沿用已確認的角色方向。自動測試、檔案存在或超時都不能視為批准。
- tests/unit_voice_suite.tscn與tests/test_unit_voice_assets.py驗證資源、播放決策、真实入口與生成失敗處理。headless不是人工GUI／母語聽感驗收。

- 忍者新增例外：英文低沉男性Callum，SELECT/INSPECT各2句「I smell magic in the air.」「Be quick; time is mana.」；MOVE兩句「Watch and learn」「Very clever」；ATTACK三句原創短句。variation_counts明確記錄2／3句配置，其他首批兵種仍保持每事件3句。此為voice-only接入，不改F2試玩、技能、數值、編隊或國籍。

- Malfory：使用者選英語女聲，新增Lily – Velvety Actress成熟魅惑英式女性聲線；SELECT/MOVE/ATTACK/INSPECT各3段。正常倉庫招募／取出及實際出戰接入，總配置34／音訊258。只改語音引用，不改Crucio、Avada Kedavra、係數、立繪或編隊。

- 2026-10-14 轉珠 UX 例外：PuzzleBattle 的有效玩家 attack cue 透過 puzzle_attack 播放該兵種 ATTACK，回合等待音檔長度後繼續，故不套用 RTS 指令冷卻。失焦暫停音檔、返回或取消停止；缺資產及靜音安全略過。一般 RTS request/acknowledge 行為不變。

- 2026-10-14 最新快速轉珠修正優先：語音不得阻塞攻擊或棋盤輸入。PuzzleBattle背景語音佇列依兵種去重、單通道播放；死亡／靜音／退場清理，RTS節流不變。
