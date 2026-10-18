# 轉珠世界驗證 — 2026-10-14

## 已執行

- 轉珠專項 headless：185通過、0失敗。涵蓋棋盤、天降、公式、零Combo、滑鼠／觸控、
  焦點通知、切換鎖、完整隊伍、召喚物／投射物暫停、返回混合戰場、正式死亡與獎勵去重。
- 轉珠專項實際渲染：186通過、0失敗；額外包含直式視窗版面檢查。
- 舊存檔補40隊、原隊伍／出生槽／玩家狀態保留、遭遇鎖延後、實際磁碟保存與重開、
  高速怪合法半徑路徑、當次任務前地圖入口／原怪域完整比較通過。
- 實際結算注入一次寫入失敗：SAVE_BLOCKED不回圖；重試成功保存收據，重複勝利不重發。
- `entry_persistence_suite`：30通過；含正式磁碟及地城／戰鬥返回。
- `tests/run_all.gd`預設世界契約／移動檢查：103通過、0失敗。
- `world/movement_regression --render`：40通過，含實際sprite／camera與30／120FPS。
- 擴展回歸的multi-party、additive-population、victory-cleanup、dynamic-reinforcement、
  background-music、ice-wall、world-map等子套件通過；詳細原始結果見下方紀錄。

## 實體滑鼠與渲染

使用computer-use的Windows滑鼠在 `tests/puzzle_playthrough.tscn` 視窗點擊怪物、拖珠，
已記錄遇敵、Combo、返回RTS、勝利及回大地圖。`physical-input.json` 記錄隔離狀態與成功結果；
`physical-victory.png` 是原戰場實際勝利畫面。此fixture刻意使用簡化敵人／棋盤，
不代表正式40隊人口的長時間難度平衡驗收。

`puzzle_world_suite --render` 另外以真實Viewport事件測滑鼠／觸控，並輸出棋盤、
四屬性預覽、直式視窗、返回戰場與勝利截圖。這些是程式驅動渲染證據，與上述OS滑鼠驗收分開。

## 完整舊測試仍未全綠

最初 `run_all --all` 為111通過／20失敗，保存於 `artifacts/puzzle-world/full-regression.json`。
其中固定22隊／21隊及4棲地的三項舊假設，已改為現行人口契約；怪區複製檢查改用
現行Polygon2D來源而非退役的隱藏Resource域。預設世界套件重跑103/0。

其餘17項擴展子套件未全部修復，包含舊技能／數值期望、歷史地圖比對與舊索引錯誤。
沒有降低既有移動、冰牆、地形與美術保護斷言。利用任務前檔案建立獨立baseline，
重跑progression、new_units、farm_boar：失敗清單與修改後完全一致，證據在
`artifacts/puzzle-world/baseline-comparison.json`。其餘失敗未全部逐一做baseline歸因，
因此不能宣稱整個專案無回歸。

Godot測試結束仍報既有ObjectDB／RID釋放警告，baseline同樣重現；不能把exit0當成無警告。
本次未進行Web匯出或部署。

## 檔案

所有新證據位於 `artifacts/puzzle-world/`；專項摘要 `headless.json`／`render.json`，
完整子套件日誌位於 `artifacts/world/`。正式功能只引用 `features/puzzle/` 與外部怪物Resource，
不引用baseline或生成圖片暫存位置。原圖與提示見 `art-provenance.json`，任務前備份見 `before/`。

## UX 更新驗證（游標跟隨／攻擊語音）

- Godot 匯入通過；轉珠 headless 193／0，實際渲染 194／0。
- 新增檢查涵蓋滑鼠與觸控位置跟隨、失焦不移動、按兵種選取 ATTACK、等待完整音檔、語音失焦暫停／恢復、靜音。
- 原語音回歸 unit_voice_suite：502 項通過；MOVE 實際渲染：40 項通過。
- 畫面證據 artifacts/puzzle-world/cursor-held-orb.png；原檔備份及四份差異見 artifacts/puzzle-ux/。
- 這次是程式驅動 Viewport 與音訊播放介面驗證，沒有新增人工聽感或 OS 滑鼠驗收。
- 本輪完整 run_all --all 已啟動，但在 ice_wall_ai_regression 尚未產生完成摘要；不能宣稱完整回歸通過。原專案已有的完整回歸失敗記錄仍保留於前節。

## 即時冷卻更新驗證

Godot 匯入通過；轉珠專項 headless203項通過，後續新增死亡兵種佇列檢查後，渲染205項通過。涵蓋秒數到期、跨多次冷卻的大delta、待機／拖珠／消除／下落／語音出手期間攻擊、失焦／轉場凍結、即時敗北與死亡兵種取消後續攻擊。既有離開引擎時的資源釋放警告仍存在。此輪未重跑全專案回歸，未新增人工操作及難度平衡驗收。

## 神抄之塔交付驗證

- 新地城渲染整合59項通過：原生地圖驗證、河灣入口可達、原地形／入口保留、28隊及4王、實際等級HP、混合怪物各自冷卻／傷害、穩定外部Resource路徑、隔離磁碟存檔、入口往返、正式GameDirector王戰與勝利結算。
- 轉珠專項headless204項通過；持久化30項、預設世界與MOVE104項、MOVE渲染40項通過；Godot匯入及文件索引通過。
- 新入口是使用者要求的添加，因此原轉珠保護檢查改為逐一核對所有舊入口與到達點仍一致，容許額外入口；未降低原地形與怪區檢查。
- 截圖：artifacts/shenchao-tower/tower-entry.png、king-battle.png；任務前備份：同目錄before/。
- 截圖與流程均為程式驅動，不是實體滑鼠人工通關。擊殺結算檢查使用測試注入HP歸零，不代表正式數值已人工擊敗。未完成長時間難度平衡、全套舊擴展回歸或Web發布。既有退出資源釋放警告仍存在。

## 快速連續轉珠

取消語音延長controller.delay，改為獨立出手佇列與背景語音佇列。轉珠渲染206項通過（包含下一輪拖珠與上一輪傷害同時進行）、神抄之塔59項通過。新增按兵種去重與靜音清理，原有音訊設定不變。此輪是自動Viewport／控制器驗證，未新增人工操作或完整專案回歸。退出資源釋放警告仍存在。

## 挑戰強化與天界地形（2026-10-14）

- 河灣轉珠怪 HP16倍、首次6–9秒／冷卻7.5秒；塔內 HP16／20／24／80倍、冷卻8／7／6／2.5秒。四王首次2.5–3.5秒、新擊殺後20–30秒重生。
- 原生探索與戰場已整合白金地磚、金色護欄、四色法陣、雲海及原創天界城堡；轉珠王戰使用專屬背景。雲海材質以世界座標鏡射連續取樣，避免平鋪接縫，原PNG保持不變。
- Godot匯入、文件索引通過。塔流程渲染60／0、數值遷移／原生幾何8／0、轉珠headless205／0及渲染206／0、持久化30／0、MOVE渲染40／0。
- 數值遷移驗證保留受傷比例、身份、等級、位置、槽位計時與玩家進度，暫停／遇敵鎖定時延後，重複載入不重套。已存在的死亡重生截止時間不重設。
- 河灣與少林探索／戰場的原始SHA256保持一致；塔的通行區、障礙、入口、戰場部署區與本輪備份一致。
- 截圖：`artifacts/shenchao-tower/tower-celestial-overview.png`、`tower-celestial-crown.png`、`tower-celestial-arena.png`、`king-battle.png`。備份、素材來源與SHA256：`artifacts/tests/tower-challenge/`。
- 既有combat_empower_suite為39通過／1失敗：其全怪物檢查要求minimum_ai_cast_time>0，轉珠／塔怪在本輪前即使用預設0，攻擊由獨立轉珠計時器處理。沒有為通過此泛用檢查而添加無關RTS施法延遲。
- 渲染與通關流程為自動Viewport／測試事件驗證，擊殺結算仍使用測試歸零HP，不代表人工已擊敗正式數值。長時間平衡與實體操作未驗收；退出時RID／ObjectDB／Resource釋放診斷仍存在。此輪未執行Web匯出或部署。

- 本輪完整 `run_all --all` 完成：128通過／17失敗，與前輪 `artifacts/tests/ui-feedback/validation.json` 的失敗清單完全一致，沒有新增失敗。耗時827秒。多隊62／0、人口同步17／0及勝利清理回歸通過；完整紀錄 `artifacts/tests/tower-challenge/full-results.json`。此為歷次結果對照，未重跑還原前版本的乾淨基線。

## 打擊回饋（2026-10-15）

Godot匯入、轉珠headless214項、渲染215項、MOVE渲染40項通過。新增檢查：攻擊保存Combo、強度遞增與封頂、並發數量及震幅限制、目標獨立閃白、效果清理、特效不改輸入／棋盤／計時、拖珠與多重受擊同時運作、失焦暫停。artifacts/puzzle-world/impact-low-high-combo.png與impact-burst.png使用測試cue對照1／10Combo，非人工實戰截圖。原圖、塔背景與傷害公式不變。未重跑完整舊回歸；已有退出資源釋放警告仍在。

## 強化王群與黑暗珠海（2026-10-15）

轉珠214項、世界預設105項、持久化30項通過；塔渲染整合新增雙王、12–18黑暗怪、個別冷卻與HP、舊存檔補到48隊、原隊伍位置／編制與玩家進度保留、遭遇鎖延後同步。截圖artifacts/shenchao-tower/dark-horde.png；修改前備份artifacts/tower-dark/before/。測試勝利仍以注入HP歸零驗證結算，不代表實際通關或平衡。既有退出資源釋放警告保留；未跑完整舊擴展回歸、未發布Web。

## 2026-10-15 暗密空間與轉珠之鬼

本輪是本地可玩整合，沒有Web發布。地圖 `features/world/data/shenchao_abyss.tscn` 可F6隔離啟動。

已完成自動化：
- Godot匯入：exit0；暗密空間44項（含渲染）、塔97項、轉珠214項、塔數值遷移8項、預設世界106項、非headless MOVE40項通過。
- 暗密空間涵蓋：合法塔頂路線與出口、13隊/5區、唯一Lv100 Boss與144–216隻黑暗怪、外部單位Resource、舊48隊塔只移除黑暗12隊、其他槽/隊伍/玩家/河灣完全一致、遇敵鎖與暫停延後、重複同步不改動、磁碟checkpoint及返回。
- GameDirector真實場景：河灣入口→塔→暗密空間→5秒遇敵→原生RTS→首次出手轉珠→返回→原勝利結算；分別覆蓋黑暗群與單體轉珠之鬼。退出驗證直接把敵方HP設零，因此不是人工拖珠擊殺、也不是完整難度平衡驗收。
- 渲染截圖：`artifacts/secret-abyss/abyss-overview.png`、`final-ghost.png`、`dark-horde.png`。已人工目視檢查輸出圖；未聲稱真人操作/實體滑鼠全程通關。
- 新資產原圖未改寫：`assets.json`記錄來源尺寸和SHA256，`image-prompts.json`記錄提示，`files.json`記錄交付檔案雜湊；`before/`保存本輪核心修改前檔案。

未通過的其他檢查：entry_persistence_suite29通過/1失敗，診斷定位到 `rainbow_temple.tscn::Resource_hrt48` 的內嵌代表/單位引用；新暗密空間引用全部通過。farm_boar_suite39通過/1失敗是舊入口精確相等fixture與後增入口不符，本輪沒改河灣。原塔小地圖有負Rect2警告，以及Godot退出RID/ObjectDB洩漏診斷；沒有把含這些診斷的完整測試宣稱全綠。

完整 `run_all --all` 本次未完成：已跑到新增人口回歸，記錄124個PASS，但包含多個舊回歸失敗；作者工具歷史fixture缺失曾造成停滯。另發現其他彩虹地城工作同時在執行完整runner、共用artifacts/world子日誌，已只停止本輪puzzle runner及其子程序，保留另一工作。不能將這次完整跑測視為可靠的全套驗收。主程序輸出備份 `artifacts/secret-abyss/full-suite-incomplete.log`；上述獨立專項suite結果另行保留。
