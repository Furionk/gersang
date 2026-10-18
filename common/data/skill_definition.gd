@tool
class_name SkillDefinition
extends Resource
enum Effect { BLAST, LIGHTNING, SUPPLY, CONTROL, HEAL, CRITICAL, QUAKE, WHEEL, DRAGON, SUMMON, ICE_WALL, LIFE_STEAL, FLAME, STAKES, STEALTH, FIRE_TRAIL, CHAIN_LIGHTNING, BUFF, CLAW_STRIKE, CHARGE, ATTACK_FLAME, CURSE, HEALTH_BURST, SOUL_DRAIN, TELEPORT, PETRIFY, SHOCKWAVE }
enum Target { GROUND, SELF, ALLY, ENEMY, DIRECTION }
enum Trigger { MANUAL, ATTACK_HIT, AUTO_SUPPORT }
@export_group("技能")
## 穩定識別ID，用於存檔與技能合併；複製新種類時改成獨立ID，不要只改顯示名稱。
@export var id: StringName
## 畫面與Inspector顯示的中文名稱，不改變存檔ID。
@export var display_name: String
## 技能／物品用途說明，供玩家查看；不會自行改變機制。
@export_multiline var description: String = ""
## 實際技能機制；BLAST爆破、QUAKE地震、DRAGON直線火龍、SUMMON召喚、ICE_WALL冰牆。
@export var effect: Effect = Effect.BLAST
## 瞄準類型：SELF自身、ALLY友軍、ENEMY敵軍、GROUND地面、DIRECTION方向。
@export var target_mode: Target = Target.GROUND
## 觸發方式：MANUAL手動、ATTACK_HIT普攻命中被動、AUTO_SUPPORT支援自動施法。
@export var trigger: Trigger = Trigger.MANUAL
## InputMap指令名稱。不同手動技能應使用不同Action，避免快捷鍵互相覆蓋。
@export var action: StringName = &"skill_blast"
## 資源預設快捷鍵；可直接選字母。玩家遊戲內自訂鍵優先，可按『跟隨資源』取消覆蓋。
@export var default_key: int = KEY_NONE
## 技能圖集中的格子索引，從0開始；只影響圖示。
@export var icon_index: int = 0
## 自動／被動用途標記；敵人主动技能AI另由Ai Enabled控制。
@export var automatic: bool = false
## 允許敵人AI嘗試此技能，仍需足夠MP、合法目標與射程。
@export var ai_enabled: bool = false
@export_group("AI決策／命中被動（不改技能冷卻）")
## 敵人隔多少秒重新嘗試技能；不是技能冷卻。
@export_range(0.1, 30.0, 0.1) var ai_attempt_interval: float = 2.0
## 每次AI嘗試的施放機率；0不施放，1必定嘗試。
@export_range(0.0, 1.0, 0.01) var ai_cast_chance: float = 1.0
## 暴擊倍率隨機範圍下限；與Max相同時固定倍率。
@export_range(1.0, 5.0, 0.05) var critical_multiplier_min: float = 1.0
## 暴擊倍率隨機範圍上限；例如Min2、Max3代表2至3倍。
@export_range(1.0, 5.0, 0.05) var critical_multiplier_max: float = 1.0
## 吸血比例，按實際扣除的HP計算；0.3代表30%，不對MISS或超額傷害吸血。
@export_range(0.0, 1.0, 0.01) var life_steal_ratio: float = 0.0
@export_group("施法")
## 自身技按快捷鍵／圖示立即執行；一般技能仍需左鍵確認。
@export var instant_self_activation: bool = false
## 每次合法施放消耗的MP。無效目標／無效公式不扣。
@export var mana_cost: float = 20.0
## 施法距離（世界單位），不是畫面像素；超出範圍時需接近。
@export var range: float = 240.0
## 全戰場施法／直線射程；依目前Scene大小計算，不受Range限制。
@export var battlefield_range: bool = false
## 效果或區域的邏輯半徑（世界單位）；等角畫面會呈現為橢圓。
@export var radius: float = 95.0
## 前搖秒數；0表示命令接收時即時施放。
@export var cast_time: float = 0.0
## 施放後冷卻秒數；目前正式技能預設0，不等於AI嘗試間隔。
@export var cooldown: float = 0.0
## 持續秒數；持續技能還會使用Effect Data內的專用配置。
@export var duration: float = 3.0
## 每次普攻實際命中的被動觸發機率；0完全不觸發，1必定觸發。
@export_range(0.0, 1.0, 0.01) var proc_chance: float = 0.1
@export_group("傷害與效果")
## 每次命中／tick的基礎傷害公式，例如strength*2、intelligence*0.5；不是整段持續的總傷害。
@export_multiline var damage_formula: String = "attack"
## 公式結果倍率。3表示公式×3；只套用一次，不隨特效數量增加。治療／補給同樣可用。
@export_range(0.0,20.0,0.1) var formula_multiplier:float=1.0
## 自動支援的判定間隔（秒），不是冷卻；需先開啟自動施法。
@export_range(0.05,2.0,0.01) var support_interval:float=0.24
## 公式留空時使用的固定基礎效果數值。
@export var power: float = 45.0
## PHYSICAL物理或MAGIC法術，決定套用防禦／物抗或法抗。
@export var damage_type: CombatMath.Kind = CombatMath.Kind.MAGIC
## 持續、移動、召喚、冰牆與特效的細節Resource；共用時修改會影響所有引用技能。
@export var effect_data: SkillEffectDefinition
## 呈現顏色，不改變傷害或通行。
@export var tint: Color = Color(1.0, 0.6, 0.2)
func manual() -> bool:
	return supports_autocast() or (trigger == Trigger.MANUAL and not automatic)
func supports_autocast() -> bool:
	return target_mode == Target.ALLY and effect in [Effect.HEAL,Effect.SUPPLY]
func result(stats: Dictionary) -> Dictionary:
	var value:Dictionary=DamageFormula.evaluate(damage_formula, stats) if damage_formula != "" else {"valid":true, "value":power, "error":""}
	if value.valid:value.value=float(value.value)*maxf(0,formula_multiplier)
	return value

func config_summary()->String:
	if effect_data==null:return "支援判定間隔 %.2f 秒"%support_interval if supports_autocast() else "範圍半徑 %.0f"%radius
	var data:SkillEffectDefinition=effect_data
	match data.kind:
		SkillEffectDefinition.Kind.LINE:return "傷害帶寬 %.0f｜呈現 %d 道｜速度 %.0f"%[data.width,data.line_visual_count,data.speed]
		SkillEffectDefinition.Kind.SUMMON:return "同時上限 %s｜持續 %.1f秒｜召喚者加成見Effect Data"%["無上限" if data.summon_limit==0 else str(data.summon_limit),data.duration]
		SkillEffectDefinition.Kind.CHAIN:return "目標 %d｜每目標電球 %d｜間隔 %.2f ± %.2f秒"%[data.chain_targets,data.chain_orbs,data.tick_interval,data.chain_interval_jitter]
		SkillEffectDefinition.Kind.FOLLOW:return "追蹤速度 %.0f｜傷害半徑 %.0f｜間隔 %.2f秒"%[data.follow_speed,radius if data.use_skill_radius else data.radius,data.tick_interval]
		SkillEffectDefinition.Kind.STORM:return "%d波 × 每波%d雷｜波間隔 %.2f秒｜单雷半徑 %.0f"%[data.storm_waves,data.storm_strikes,data.storm_interval,data.storm_impact_radius]
		SkillEffectDefinition.Kind.BUFF:return "攻擊×%.2f｜攻速×%.2f｜追加射程%.0f"%[data.attack_multiplier,data.attack_speed_multiplier,data.attack_range_bonus]
	return "半徑 %.0f｜每 %.2f秒｜持续 %.1f秒"%[radius if data.use_skill_radius else data.radius,data.tick_interval,data.duration]
