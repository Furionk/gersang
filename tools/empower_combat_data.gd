extends SceneTree
## Explicit one-shot author step. Never a runtime hook or layout generator.
const OUT:String="res://artifacts/combat-empower-2026-10-13/"
var changes:Array[Dictionary]=[]
func _initialize()->void:call_deferred("run")
func save(data:Resource)->void:assert(ResourceSaver.save(data,data.resource_path)==OK)
func skill(id:String)->SkillDefinition:return load("res://features/skills/data/"+id+".tres")
func fields(data:Resource,values:Dictionary)->void:
	var before:Dictionary={}
	for key:String in values:before[key]=data.get(key);data.set(key,values[key])
	changes.append({"path":data.resource_path,"before":before,"after":values})
func run()->void:
	if FileAccess.file_exists(OUT+"data-applied.json"):push_error("Combat data already authored; refuses rerun over Artist changes.");quit(1);return
	# Strengthen all friendly-owned skills, then apply explicitly requested exceptions.
	var seen:Dictionary={}
	for name:String in DirAccess.get_files_at("res://features/units/data/mercenaries"):
		if not name.ends_with(".tres"):continue
		var unit:UnitDefinition=load("res://features/units/data/mercenaries/"+name)
		for owned:SkillDefinition in unit.skills:
			if seen.has(owned.resource_path):continue
			seen[owned.resource_path]=true
			if owned.effect in [SkillDefinition.Effect.SUMMON,SkillDefinition.Effect.BUFF,SkillDefinition.Effect.STEALTH,SkillDefinition.Effect.ICE_WALL]:
				if owned.effect_data!=null:owned.effect_data.duration*=1.35
			else:owned.formula_multiplier=1.7
			save(owned)
	var blast:SkillDefinition=skill("blast");fields(blast,{"radius":300.0,"formula_multiplier":3.0,"description":"自身半徑300暴雷（可改Radius），固定爆破點逐圈擴散。每目標每施放一次傷害＝原公式×Formula Multiplier，預設3。"});blast.effect_data.use_skill_radius=true;blast.effect_data.radius=300;save(blast)
	var dragon:SkillDefinition=skill("dragon");fields(dragon,{"formula_multiplier":3.0,"display_name":"猛擊火龍破","description":"全戰場定向貫穿。Effect Data Width控制傷害帶，Line Visual Count控制多條火龍；同一命中不因圖片數量倍增。原公式×3。"});dragon.effect_data.width=120;dragon.effect_data.line_visual_count=3;dragon.effect_data.trail_length=240;save(dragon)
	var quake:SkillDefinition=skill("quake");quake.formula_multiplier=3;quake.effect_data.use_skill_radius=true;save(quake)
	var lightning:SkillDefinition=skill("lightning");fields(lightning,{"radius":220.0,"formula_multiplier":2.0,"description":"指定區域多波隨機落雷；波數、每波雷數、波間隔、單雷半徑都在Effect Data。每道實際落雷獨立判定，不是只換動畫。"});lightning.effect_data.kind=SkillEffectDefinition.Kind.STORM;lightning.effect_data.storm_waves=4;lightning.effect_data.storm_strikes=5;lightning.effect_data.storm_interval=0.22;lightning.effect_data.storm_impact_radius=75;save(lightning)
	var avada:SkillDefinition=skill("avada_kedavra");avada.formula_multiplier=1;avada.effect_data.target_max_hp_ratio_formula="0.35+intelligence*0.001";avada.description="0.5秒施法：目標最大HP×(35%＋每點智慧0.1%)，法抗照常。僅我軍新版；幻象維持舊公式。";save(avada)
	var summon:SkillDefinition=skill("summon");summon.effect_data.summon_limit=0;summon.effect_data.duration=45;summon.effect_data.summon_attack_bonus_formula="agility*4+strength";summon.effect_data.summon_health_bonus_formula="agility*8+strength*10";summon.description="忠臣之魂無同時數量上限（Summon Limit=0），每隻45秒。射速與前搖在spirit.tres設定，能力加成在Effect Data。";save(summon)
	var spirit:UnitDefinition=load("res://features/units/data/summons/spirit.tres");fields(spirit,{"max_health":850.0,"damage":65.0,"attack_interval":0.06,"attack_windup_override":0.025,"attack_range":420.0,"accuracy":160.0});save(spirit)
	var claw:SkillDefinition=skill("earth_claw");claw.mana_cost=35;claw.effect_data.duration=40;claw.effect_data.summon_health_bonus_formula="intelligence*20";claw.effect_data.summon_defense_bonus_formula="intelligence*1.2";claw.effect_data.summon_intelligence_bonus_formula="intelligence*1.4";claw.description="X即時召喚，MP35（可改）、無數量上限、40秒；智慧加體力/防禦/刺擊，自己的地樁區仍有協同。";save(claw)
	var claw_unit:UnitDefinition=load("res://features/units/data/summons/earth_claw.tres");claw_unit.attack_interval=0.28;claw_unit.attack_windup_override=0.04;save(claw_unit)
	var strike:SkillDefinition=skill("claw_strike");strike.formula_multiplier=3;strike.radius=115;strike.effect_data.radius=115;save(strike)
	for id:String in ["heal","supply"]:
		var support:SkillDefinition=skill(id);support.support_interval=0.10;support.formula_multiplier=2;support.range=360;support.description="更快速支援：自動判定間隔Support Interval0.10秒，原公式×2。右鍵技能切換自動；不對已滿目標浪費施法。";save(support)
	var chain:SkillDefinition=skill("ninja_chain");chain.effect_data.chain_orbs=4;chain.effect_data.tick_interval=0.5;chain.effect_data.chain_interval_jitter=0.02;chain.effect_data.chain_targets=6;chain.effect_data.chain_jump_range=240;chain.effect_data.duration=6;chain.effect_data.hit_control_duration=0.12;chain.formula_multiplier=1.8;chain.description="C指定敵人；最多6個敵人各有4顆環繞電球，每球0.48–0.52秒獨立電击。Tick Interval、Jitter、Chain Orbs、Jump Range可調。";save(chain)
	var trail:SkillDefinition=skill("ninja_fire_trail");trail.radius=100;trail.effect_data.radius=100;trail.effect_data.use_skill_radius=true;trail.effect_data.tick_interval=0.35;trail.effect_data.trail_point_lifetime=5;trail.formula_multiplier=2;trail.description="立即啟用加寬火徑；Radius100、每0.35秒原公式×2，火點保留5秒。同一條重疊火徑不重複計同一tick。";save(trail)
	var wheel:SkillDefinition=skill("wheel");wheel.formula_multiplier=3;wheel.radius=120;wheel.effect_data.use_skill_radius=true;wheel.effect_data.radius=120;wheel.effect_data.follow_speed=550;wheel.effect_data.tick_interval=0.18;wheel.effect_data.duration=10;wheel.description="從施法者出發，按Follow Speed550追到敵人後持續跟隨10秒，每0.18秒原公式×3。速度、半徑、間隔、持續都可調。";save(wheel)
	var wave:SkillDefinition=skill("blood_moon_wave");wave.effect_data.width=240;wave.effect_data.line_visual_count=3;wave.effect_data.blood_wave_visual=true;wave.effect_data.trail_length=240;wave.formula_multiplier=1.5;wave.description="血色多道劍弧；Width240是實際傷害寬度，Line Visual Count只是呈現。Formula Multiplier控制威力；最終幻影仍只打原形的半傷害。";save(wave)
	# Each foe gets a distinct, authored threat/weakness. Never reroll composition.
	var casters:Array[String]=["school_dementor","blood_wraith","well_blood_wraith","deep_well_blood_wraith","shaolin_thunder_warden","shaolin_flame_keeper","well_pyromancer","deep_well_pyromancer","ember_raider","millennium_bird","kohime_enemy","voldemort_illusion"]
	var tanks:Array[String]=["school_gatekeeper","well_earth_sentinel","deep_well_shock_guard","earth_brute","shaolin_iron_disciple","shaolin_copper_master","shaolin_elite_copper","shaolin_grandmaster","shaolin_guardian","lake_guardian","ganondorf_phantom","ganondorf_echo","boss","elite"]
	var swift:Array[String]=["school_dark_elf","school_cerberus","millennium_wolf","shaolin_swift_disciple","shaolin_shadow_captain","ninja_enemy","bloodfang"]
	for name:String in DirAccess.get_files_at("res://features/units/data/monsters"):
		if not name.ends_with(".tres"):continue
		var data:UnitDefinition=load("res://features/units/data/monsters/"+name);var id:String=String(data.id)
		var values:Dictionary={"max_health":data.max_health*1.8,"damage":data.damage*1.5,"mana_regeneration":maxf(data.mana_regeneration,6.0),"balance_revision":1}
		if id in tanks:
			values.merge({"strength":data.strength+35,"defense":maxf(90,data.defense*1.8),"armor":maxf(data.armor,0.45),"magic_resistance":0.08,"tactical_hint":"重甲高體力：用法術／持續地面技削血，前排拉住，不要只靠普通物理硬打。"})
		elif id in casters:
			values.merge({"intelligence":data.intelligence+30 if id!="voldemort_illusion" else data.intelligence,"magic_resistance":0.60,"armor":0.03,"defense":maxf(8,data.defense*0.7),"tactical_hint":"高法抗施法者：用物理射手／忠臣之魂集中火力，控制中斷施法；不要一直用同種法術。"})
		elif id in swift:
			values.merge({"agility":data.agility+25,"speed":data.speed*1.12,"evasion":minf(0.25,data.evasion+0.10),"armor":0.08,"magic_resistance":0.18,"tactical_hint":"高速突擊：先控場／火路封位再集火，分散避開直線衝鋒；用高命中或範圍技能。"})
		else:
			values.merge({"vitality":data.vitality+30,"defense":data.defense+20,"armor":maxf(data.armor,0.12),"magic_resistance":0.18,"tactical_hint":"成群消耗：聚怪後用範圍雷擊／暴雷；吸血與分裂種要快速集火，不要逐個慢磨。"})
		fields(data,values);save(data)
	var style:BattlePhasePresentation=BattlePhasePresentation.new();var style_path:String="res://features/units/data/phases/blood_moon_presentation.tres";assert(ResourceSaver.save(style,style_path)==OK);style.take_over_path(style_path)
	var phase:MonsterPhaseDefinition=load("res://features/units/data/phases/voldemort_blood_moon.tres");phase.presentation=style;phase.title="末日來了";save(phase)
	var file:FileAccess=FileAccess.open(OUT+"data-applied.json",FileAccess.WRITE);file.store_string(JSON.stringify({"changes":changes,"illusion_formula_unchanged":true,"layouts_untouched":true},"\t"));file.close()
	print("COMBAT_EMPOWER_DATA_SAVED changes=",changes.size());quit()
