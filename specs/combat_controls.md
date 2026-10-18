# 戰鬥操作 V3 — 2026-10-09

依使用者本輪六項要求，取代早期 V2 的冷卻、按住連射／Ctrl連射、自身技按鍵即放及E直接施法操作。來源世界設計快照保持不變；此輪不修改導航／移動契約。

- UX-01：測試與截圖隔離正式進度／存檔，素材、公式、兵種與既有裝備保留。
- UX-02（D12）：F1是保留 action `toggle_cursor_lock`；世界、倒數、戰鬥皆可切換可見游標的視窗限制，不是隱藏／置中的FPS capture。再次F1解鎖；失焦／選單／載入／戰果暫釋放實際限制，但保留session偏好，返回可玩畫面恢復；節點離樹完全清除。不得重綁其他指令到F1。
- UX-03：SkillDefinition.cooldown預設0，全部現有技能資源設定0；commit只讀skill.cooldown，不再用repeat_interval作額外CD。cast_time、效果duration／tick、MP、普通攻擊interval保持各自含義。
- UX-04：一般玩家手動技能是「鍵／圖示準備 → 左鍵確認 → 固定tick施法 → 清空瞄準」。再施放必須再次準備／確認。SELF固定到施法者的位置，不用鼠標地點作爆炸中心。**D17例外：暴雷擊的I／圖示直接提交自身施法，不需左鍵。**
- UX-05：按住／key echo／Ctrl不能沿用舊目標連射；旧profile值和repeat命令不得繞過確認。E仍可依序準備下一位可用施法者，會選取該單位，但也須左鍵指定，不自動挑目標。敵人AI和明確啟用的自動補給是獨立的自動行為。
- UX-06：ALLY／ENEMY技能直接點存活且隊伍合法的單位；指向游標，不畫範圍／射程圈。無效目標不花MP、保留瞄準。地面範圍、方向線與冰牆預览照舊；選兵底圈和真實技能特效不是指向圈。
- UX-07：有效單位施法命令、普通右鍵指定攻擊，僅讓實際目標sprite短暫閃爍0.32秒；不代表已命中或已造成傷害。無選兵／無效目標不給假確認。顯示狀態只由UnitView持有，不改位置、碰撞、HP或共有圖集。
- UX-08：HEAL／SUPPLY支持右鍵技能圖示切換，左鍵仍可手動。每名AbilityController獨立保存autocast；共用SkillDefinition不變。混合多選時右鍵開啟所有該技能所選持有者，全開時右鍵全部關閉；缺魔仍可切開關。恢復沿用預設開、補給預設關。
- UX-09：自動補給只選射程內、同隊存活且有缺值的最低百分比友軍，不追遠距人、不浪費於已滿目標；MP不自補防止自動循環。選人約0.24秒輪詢不是技能CD。攻擊命令可暫停補給並恢復原目標／佇列；明示移動和正在執行的施法不被自動技能打斷。

## D17：暴雷擊即時自身等角圓爆破（2026-10-10）

- NOVA-01..04：使用者明確選定「按I／圖示即時施放」。SkillDefinition.instant_self_activation預設false，blast.tres設定true；只對SELF生效。輸入直接提交同一AbilityController命令，下一固定tick以0前搖釋放，不等待AI思考或普攻間隔。新按鍵／圖示可再施放，仍有MP資格、CD0且key echo不連射。
- NOVA-05/06：缺魔不打斷舊命令／不花MP。所選多名持有者一起提交各自中心。E序列維持準備＋左鍵，透過prepare_only入口，不把其他技能或E改成自動亂放。
- NOVA-07/08：不是8顆爆炸sprite沿半徑移動。半徑內固定平面格點，逐層亮起完整範圍；150範圍為29個對稱格點，0／0.2／0.4／0.6／0.8秒顯示1／5／9／21／29格。位置用Iso.project映射，範圍視覺2:1橢圓；每個sprite的地面位置與尺度均固定，只播放各自爆破幀。
- 中心保存成功釋放時caster位置，移動施法者不拖著爆破跑。原爆炸圖集不改、共用原材質；地面薄光圈是真實效果，不是施法指向圈。
- 維持一秒內五段權威傷害、每目標每次施放最多一次、strength*2、MP28、CD0；FPS不改傷害tick。沒有新增直接輸入處理HP或改世界移動。
- 入口 `tests/blast_radial_suite.tscn`、既有v2／combat_ux／progression及完整--all；實際渲染 `artifacts/world/blast-layer-0..4.png`，結果JSON `blast-radial-headless/render-results.json`。

## 狀態所有權與接口

- `SelectionController.activate_skill/confirm_skill`：準備／確認；`toggle_autocast`：所選持有者開關；`preview_kind`：明確描繪類型。GUI與快捷鍵共用。
- `AbilityController`：每單位 MP資格、cooldowns、autocast及附近support_target；共用資源不持有可變模式。
- `TacticalUnit.tick/_auto_support`：固定更新與命令恢復；導航、速度、轉向、位移算術不變。
- `BattleCursorGuard`：獨立、戰鬥限定的視窗游標生命週期；GameDirector負責場景退出釋放，HUD只讀狀態。
- `UnitView.confirm_target`：獨立短暫呈現，不是傷害事件。

驗證入口 `tests/combat_ux_suite.tscn`，另外保留全部既有測試和MOVE。舊測試中不再合法的連射／自身技按鍵即放斷言改成上述新契約，不能削弱移動／技能效果／冰牆測試。實際物理游標出界測試與engine模式／焦點測試要分開報告。

## UI-2026-10-15：技能與 RTS 操作回饋

- X 優先關閉最上層一般視窗，沒有視窗時開啟行旅選單；右下角選單圖示提供同一入口。Esc 僅保留關窗相容及既有倒數取消，不再開選單。按鍵捕捉時 X／Esc 先取消捕捉；按住不重複。結算不屬於一般視窗。
- X 現在是選單保留鍵，取代 D34 的 X 直接召喚操作。原生技能 Resource 的 default_key 不改；衝突技能標紅，仍可點圖示或在設定改鍵。
- 探索左鍵與戰鬥右鍵移動使用世界座標固定、2:1 等角橢圓淡金回饋。UI 不穿透，切場清除，最多四個。只呈現命令回饋，不修改路徑。
- 技能區依寬度排列，固定兩排後垂直捲動。底部沿用原本 148px 高度（放大字體沿用原有 grow 規則），不得隨技能數增加而侵占戰場。快捷鍵置左上；所選技能間重複或與命令保留鍵碰撞時，紅色圖示／鍵標與 tooltip 提示改鍵。
- 補給／恢復的手動／自動選擇依角色 persistent_id + skill_id 寫入設定檔；不改角色進度存檔 schema。自動為持續綠色繞方形圖示光效，混合為金色。仍以右鍵圖示切換；不改自動選敵／補給規則。
- ALLY／ENEMY 技能準備後顯示準星角框和點選目標文字，合法目標變綠；UI 懸停及 modal 隱藏提示。無效點擊保留瞄準；右鍵取消。
- 準備／確認／取消／無效操作共用 `features/ui/data/feedback.tres`：可指定 AudioStream、音量與無指定音檔時的短音頻率／長度。使用者設定另有 UI 音量／靜音。此 Resource 同時提供移動圈時間／大小／顏色及補給動畫時間／寬度。
- 補給／恢復使用 `features/skills/art/support/restoration-v1.png` 原創透明 4×2 動畫，綠色第一列恢復、藍色第二列補給；跟隨目標並自動清除，不改數值。
- Ctrl+1…0、-、= 共 12 組，單按呼叫，重編覆寫；角色左上血條旁顯示組名。一般角色以 persistent_id 保留，召喚物只記當場 unit_id，下一場不恢復。尚未設定的數字鍵保留舊隊伍欄位選取。框選與 Shift 加選維持原行為。
- 測試入口 `ui_humanized_suite`、`ui_feedback_suite`、`combat_ux_suite`、`window_resize_regression`、完整 run_all 與 rendered MOVE。自動注入輸入／實際渲染不能替代真人 Web 全螢幕驗收。

- UI 回饋補充：缺魔手動技能保持可點，圖示變暗並顯示法力不足；滑鼠／快捷鍵共用拒絕分支，提示所需 MP、錯誤音與 0.45 秒紅框，不施法不扣魔。回魔後恢復原標籤。自動模式固定四道等距光沿方形圖示繞行。HUD 高度仍受原版限制。
