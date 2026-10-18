# D41：霍格愛茲平行地城

2026-10-13 使用者決定：一個大型地城包括庭院、幽魂迴廊、禁忌地窖、首領大禮堂。血月由原提案每秒5%改為每3秒最大HP的1%；敵我皆受影響（含首領），整場一份。保留所有舊地圖／進度／原音樂，不重新部署Web。

## 原生權威

- 世界：`features/world/data/hogwarts.tscn`，8個MonsterRegions、30隊怪；河灣新增school_door及school_return，旧入口/地景/导航保持原值。
- 戰場：`features/battle/maps/hogwarts.tscn`及`hogwarts_blood_moon.tscn`，各自五個雙方可用出生區，Ground/Walkable/Blockers仍是原生權威。
- 六種地城怪及兩個首領後續形態：`features/units/data/monsters/*.tres`；美術切分與技能必須外部引用可直接編輯的Resource。
- `MonsterPhaseDefinition`擁有下一形態、最終分身數、停頓、換景、環境扣血設定。不寫死怪物ID判定階段。

## 階段與安全

首次致死傷害：保留TacticalUnit與persistent_unit_id，清掉舊施法／控制，改為Lv90加儂幻影並回滿血。2秒期間停止指令、移動、AI、投射物、技能效果與血月時鐘；鏡頭展示首領，之後恢復。

換景只換視覺Scene，cells與blocked必須與目前導航完全一致；不符時保留原場景並顯示原因，不放寬通行規則。Actor／既有效果不因換景被刪除。

第二次致死傷害：隨機合法空位生成5個Lv90幻影，原首領正式死亡一次。後續幻影無循環death_phase、無persistent snapshot ID、無額外經驗；`outgoing_damage_scale=0.5`在防禦/抵抗後套用一次，含普攻與技能。出生受60敵人上限限制，未放完的pending阻止提前勝利。

一個BattlePhaseController持有一份血月，interval=3、max_health_fraction=0.01。fixed_damage>0時切到固定傷害模式。环境扣血不受角色輸出倍率影響。

戰鬥鏡頭平移邊界取原生cells矩形四角的Iso投影範圍，不再用固定(-1000..1150/100..1150)。大戰場所有隨機出生格可移鏡頭查看；速度、邊緣捲動與世界D09跟隨/插值不變。

最後五個幻影全滅後沿用D36可操作收尾2秒，再由SettlementService一次結算原始首領快照30000XP；舊千年湖進化路線與獎勵不改。

## 技能

吸魂：4秒持續施法、每0.5秒按attack×0.7造成法術傷害、按實際扣血量回血；走出440範圍、受到控制、死亡或更換指令會中斷。不可過量傷害吸到不存在的HP。

傳送：距離敵人130的合法未佔用落點，傳送後仍使用原生遠距普攻。石像普攻命中觸發直線衝擊波。蛇妖1秒前搖、半徑170、石化4秒。三頭犬沿用實際物理CHARGE、紅色加寬；不繞過地面Blockers/冰牆。

佛地魔Avada：`(0.5+intelligence*0.005)*0.25`乘目標最大HP，0.5秒施法；法抗照常，不額外乘假暴擊。

## 驗證

`tests/hogwarts_suite.tscn`覆蓋原生配怪、等級、往返、吸魂/傳送/石化/波、實際三階段戰鬥與一次性結算。`tests/hogwarts_art_gallery.tscn`渲染七張48姿勢切分；`tests/hogwarts_preservation.gd`對照河灣備份。其他回歸與已知舊fixture失敗詳見交付報告。

生成工具僅為本次來源記錄，禁止以create/link/polish/review工具覆蓋之後Artist修改。素材原PNG不可改寫；排序/切分/腳底以Resource調整。
