@tool
class_name SkillEffectDefinition
extends Resource
enum Kind { INSTANT, QUAKE, RADIAL, FOLLOW, LINE, SUMMON, BARRIER, CRITICAL, FLAME, STAKES, STEALTH, FIRE_TRAIL, CHAIN, BUFF, CHARGE, CURSE, HEALTH_BURST, SOUL_DRAIN, TELEPORT, STORM }
@export_group("範圍與多道直線呈現")
## true時實際圓形傷害與呈現使用Skill的Radius；只複製釋放時資料，不改共用Resource。
@export var use_skill_radius:bool=false
## 同一傷害帶顯示幾條火龍／劍波；增加圖片不會重複計傷害。
@export_range(1,12) var line_visual_count:int=1
## 直線圖片橫向覆蓋比例。1覆蓋整個Width，傷害範圍仍只有Width一份。
@export_range(0.0,1.0,0.05) var line_visual_spread:float=0.8
## 多道火龍圖片的厚度／輝光倍率，純呈現。實際傷害仍只由Width控制。
@export_range(0.5,3.0,0.05) var line_sprite_cross_scale:float=1.0
@export_group("追蹤車輪")
## 0沿用舊版直接落在敵人身上；大於0從施法者出發，按此世界速度追蹤敵人。
@export_range(0.0,2000.0,10.0) var follow_speed:float=0.0
## true時抵達才開始Duration與傷害；false包含飛行時間並可沿路傷害。
@export var follow_duration_after_arrival:bool=true
## 追不到高速目標時的飛行逾時；0不限制。抵達後仍按Duration持續跟隨。
@export_range(0.0,120.0,0.5) var follow_travel_timeout:float=15
## 額外血色劍弧／殘影，純演出、不增加傷害次數。
@export var blood_wave_visual:bool=false
@export_group("隨機多波雷擊")
@export_range(1,20) var storm_waves:int=3
## 雷擊波之間秒數，所有判定使用固定更新，不看畫面FPS。
@export_range(0.02,5.0,0.01) var storm_interval:float=0.22
@export_range(1,20) var storm_strikes:int=4
## 每一道落雷的傷害半徑；整個隨機落雷區以Skill Radius為界。
@export_range(10.0,500.0,5.0) var storm_impact_radius:float=65
@export_group("敵方環繞電球")
## 0保留原串連；大於0讓每個串連目標出現此數量電球，逐球錯開電擊。
@export_range(0,12) var chain_orbs:int=0
## 例Tick Interval0.5、Jitter0.02，每球間隔各自隨機0.48–0.52秒。
@export_range(0.0,0.5,0.005) var chain_interval_jitter:float=0.02
@export_range(15.0,150.0,1.0) var chain_orbit_radius:float=55
## 電球環繞速度（每秒弧度），僅呈現。
@export_range(0.0,12.0,0.1) var chain_orbit_speed:float=3.0
@export_group("吸魂／傳送")
## 按實際扣除HP回復施法者，不吸取超額傷害。
@export_range(0.0,2.0,0.01) var drain_heal_ratio:float=1.0
## 持續施法超出此距離中斷；0沿用技能Range。
@export var channel_break_range:float=0.0
## 傳送到敵人附近的距離，仍只選合法、不重疊落點。
@export_range(24,400,1) var teleport_separation:float=130
@export_group("智慧詛咒與百分比傷害")
## 減速比例公式；0.25+intelligence*0.001表示25%＋每點智慧0.1%。
@export_multiline var slow_percent_formula: String = "0.25+intelligence*0.001"
## 減速上限；0.8表示最多降低80%，並非剩餘移速。
@export_range(0.0,0.95,0.01) var slow_percent_cap: float = 0.8
## 目標最大HP倍率；0.5+intelligence*0.005表示50%＋每點智慧0.5%。未限制於100%。
@export_multiline var target_max_hp_ratio_formula: String = "0.5+intelligence*0.005"
## 全畫面短暫染色，透明度由Flash Opacity控制；不攔截操作。
@export var flash_color: Color = Color(0.05,1.0,0.12)
@export_range(0.0,1.0,0.01) var flash_opacity: float = 0.13
@export_range(0.05,1.0,0.01) var flash_duration: float = 0.22
## true只命中地面敵人，例如地面狼的衝鋒；飛行首領可設false。
@export var ground_targets_only: bool = false
## 此Resource／節點的機制種類，具體意義依所在分類。
@export var kind: Kind = Kind.INSTANT
## 持續秒數；持續技能還會使用Effect Data內的專用配置。
@export_range(0.0, 60.0, 0.05) var duration: float = 1.0
## 每次傷害tick之間的秒數；0.25表示每秒4次。
@export_range(0.02, 10.0, 0.01) var tick_interval: float = 0.25
## 效果或區域的邏輯半徑（世界單位）；等角畫面會呈現為橢圓。
@export var radius: float = 100.0
## 直線技能的邏輯寬度（世界單位）。
@export var width: float = 60.0
## 移動技能最遠距離（世界單位），釋放後方向固定。
@export var distance: float = 480.0
## 邏輯移動速度，單位為世界單位／秒，不是畫面像素。
@export var speed: float = 360.0
## 火龍拖尾保留長度（世界單位）。
@export var trail_length: float = 160.0
## 冰牆的邏輯長度；方向垂直於施法方向。
@export var wall_length: float = 240.0
## 減速比例；0.5代表降低50%。同類減速取最強並刷新時間。
@export var slow_factor: float = 0.5
## 減速狀態維持秒數，結束後恢復原速。
@export var slow_duration: float = 3.0
## 召喚單位的UnitDefinition資源，與一般兵／怪使用相同格式。
@export var summon_definition: Resource
## 每次召喚數量下限。
@export_range(1, 6) var summon_count_min: int = 1
## 每次召喚數量上限；需大於等於Min。
@export_range(1, 6) var summon_count_max: int = 1
## 召喚物是否使用施法者的等級。
@export var summon_inherit_level: bool = false
@export_group("召喚者能力加成（施法快照）")
## 召喚攻擊加成公式，使用釋放時施法者能力快照。
@export_multiline var summon_attack_bonus_formula: String = "0"
## 召喚命中加成公式，使用釋放時施法者能力快照。
@export_multiline var summon_accuracy_bonus_formula: String = "0"
## 共用美術／圖集路徑；不能用兵種data資料夾區分敵我美術。
@export_file("*.png") var sprite_path: String = ""
## 特效圖集是否以接地位置而非圖片中心對齊（例如從天而降的雷）。
@export var sprite_grounded: bool = false
## 接地點位於每格高度的比例；0.84代表從上方算84%。
@export_range(0.0, 1.0, 0.01) var sprite_foot_ratio: float = 0.84
@export_group("新兵種效果（釋放時快照）")
## 例如10+(agility+strength)*0.05。留空沿用Duration；不改技能冷卻。
@export_multiline var duration_formula: String = ""
## 召喚物智力額外加成。用於魔爪每次刺擊的智慧傷害；不會修改原模板。
@export_multiline var summon_intelligence_bonus_formula: String = "0"
## 召喚物最大體力額外加成，使用施法者釋放時能力（例如intelligence*12）。
@export_multiline var summon_health_bonus_formula: String = "0"
## 召喚物防禦額外加成，使用施法者釋放時能力。
@export_multiline var summon_defense_bonus_formula: String = "0"
## false代表不能選控的召喚物；只由其AI尋找附近敵人。
@export var summon_controllable: bool = true
## 同施法者召喚數上限；0表示無技能數量上限，仍每次按鍵只施放一次。
@export_range(0, 60) var summon_limit: int = 1
@export_group("召喚與主技配合")
## 必須是自己召喚者的此技能區域，才觸發配合；留空不啟用。
@export var synergy_skill_id: StringName = &""
## 對主技區域內敵人的刺擊倍率；重疊區域不疊乘。
@export_range(1.0, 5.0, 0.05) var synergy_damage_multiplier: float = 1.0
## 魔爪站在主技區域內的攻速倍率；離開或區域消失立即恢復。
@export_range(1.0, 5.0, 0.05) var synergy_attack_speed_multiplier: float = 1.0
## 暫時增益的攻擊倍率。3代表原攻擊+200%；同技能重施刷新，不疊乘。
@export_range(0.1, 10.0, 0.05) var attack_multiplier: float = 1.0
## 攻速倍率。1.5代表每秒攻擊數+50%，間隔除以1.5。
@export_range(0.1, 5.0, 0.05) var attack_speed_multiplier: float = 1.0
## 暫時移速倍率；1.2代表+20%，仍沿用正式導航。
@export_range(0.1, 3.0, 0.05) var movement_multiplier: float = 1.0
## 狙擊時額外普攻射程，世界單位。
@export var attack_range_bonus: float = 0.0
## 狙擊時額外普攻攻擊值。
@export var attack_bonus: float = 0.0
## 隱身現身後首個普攻的額外傷害公式，使用釋放時的能力快照。
@export_multiline var reveal_attack_formula: String = "0"
## 串連最多目標數；同一輪每個敵人最多命中一次。
@export_range(1, 12) var chain_targets: int = 4
## 下一個串連目標離前一目標的最大邏輯距離。
@export var chain_jump_range: float = 180.0
## 每次跳躍傷害倍率；1代表不衰減。
@export_range(0.1, 1.0, 0.05) var chain_damage_multiplier: float = 1.0
## 閃電每次命中的短暫控制秒數。
@export_range(0.0, 5.0, 0.05) var hit_control_duration: float = 0.0
## 留火路兩個火點間最少距離；原地站立不無限建立火點。
@export var trail_spacing: float = 32.0
## 火點離開後仍保留的秒數（不會超過施放效果結束）。
@export var trail_point_lifetime: float = 3.0
func resolved_duration(stats: Dictionary) -> Dictionary:
	return {"valid":true,"value":duration,"error":""} if duration_formula.is_empty() else DamageFormula.evaluate(duration_formula,stats)
