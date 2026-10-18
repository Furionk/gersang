class_name AbilityController
extends Node
signal released(skill_id: StringName)
var caster: TacticalUnit
var cooldowns: Dictionary = {}
var active_summons: Dictionary = {}
var active_summon_groups: Dictionary = {}
var ai_attempts: Dictionary = {}
var last_error: String = ""
var autocast: Dictionary = {}
var auto_scan_left: float = 0.0
func initialize(unit: TacticalUnit) -> void:
	caster = unit
func tick(delta: float) -> void:
	auto_scan_left = maxf(0,auto_scan_left-delta)
	for key: StringName in ai_attempts: ai_attempts[key] = maxf(0,float(ai_attempts[key])-delta)
	for key: StringName in active_summon_groups.keys():
		var living: Array[int] = []
		for id: int in active_summon_groups[key]:
			var unit: TacticalUnit = caster.director.get_unit(id)
			if unit != null and unit.alive(): living.append(id)
		if living.is_empty():
			active_summon_groups.erase(key)
			active_summons.erase(key)
		else:
			active_summon_groups[key] = living
			active_summons[key] = living[0]
	for key: StringName in cooldowns:
		cooldowns[key] = maxf(0, float(cooldowns[key]) - delta)
	for key: StringName in active_summons.keys():
		var unit: TacticalUnit = caster.director.get_unit(int(active_summons[key]))
		if unit == null or not unit.alive():
			active_summons.erase(key)
func available(skill: SkillDefinition) -> bool:
	last_error = ""
	if skill == null or skill not in caster.available_skills() or not caster.alive():
		last_error = "單位沒有此技能"
	elif caster.control_left > 0:
		last_error = "單位受制"
	elif caster.channeling:
		last_error="持續施法中"
	elif caster.charging and skill.trigger!=SkillDefinition.Trigger.ATTACK_HIT:
		last_error = "衝鋒中"
	elif caster.cast_left >= 0 and caster.active.get("skill") == skill:
		last_error = "施法中"
	elif float(cooldowns.get(skill.id, 0)) > 0:
		last_error = "冷卻中"
	elif caster.vitals.mana + 0.001 < skill.mana_cost:
		last_error = "法力不足"
	elif not bool(skill.result(caster.stats_snapshot())["valid"]):
		last_error = str(skill.result(caster.stats_snapshot())["error"])
	elif skill.effect_data!=null and not bool(skill.effect_data.resolved_duration(caster.stats_snapshot())["valid"]):
		last_error = "持續公式無效"
	elif skill.effect_data!=null and skill.effect_data.kind==SkillEffectDefinition.Kind.CURSE and not DamageFormula.evaluate(skill.effect_data.slow_percent_formula,caster.stats_snapshot()).valid:
		last_error = "減速公式無效"
	elif skill.effect_data!=null and skill.effect_data.kind==SkillEffectDefinition.Kind.HEALTH_BURST and not DamageFormula.evaluate(skill.effect_data.target_max_hp_ratio_formula,caster.stats_snapshot()).valid:
		last_error = "最大HP倍率公式無效"
	elif skill.effect==SkillDefinition.Effect.SUMMON and skill.effect_data==null:
		last_error = "召喚模板無效"
	elif skill.effect == SkillDefinition.Effect.SUMMON and active_summons.has(skill.id):
		var living: int=0
		var group: Array=active_summon_groups.get(skill.id,[active_summons[skill.id]])
		for id: int in group:
			var spirit: TacticalUnit = caster.director.get_unit(id)
			if spirit != null and spirit.alive(): living+=1
		if skill.effect_data.summon_limit>0 and living>=skill.effect_data.summon_limit: last_error = "召喚物仍然存在（已達上限）"
	return last_error == ""
func request(skill: SkillDefinition, point: Vector2, target_id: int = -1, _repeat: bool = false) -> bool:
	if not skill.manual() or not available(skill):
		return false
	var error: String = caster.director.validate_skill_target(caster, skill, point, target_id)
	if error != "":
		last_error = error
		return false
	if caster.cast_left >= 0 and caster.active.get("skill") == skill:
		return false
	caster.issue_command({"kind":"cast", "skill":skill, "point":point, "target":target_id})
	return true
func commit(skill: SkillDefinition, point: Vector2, target_id: int) -> bool:
	var formula: Dictionary = skill.result(caster.stats_snapshot())
	if not formula["valid"]:
		last_error = str(formula["error"])
		return false
	caster.director.resolve_skill(caster, skill, point, target_id)
	cooldowns[skill.id] = maxf(0,skill.cooldown)
	released.emit(skill.id)
	return true
func autocast_enabled(skill: SkillDefinition) -> bool:
	var fallback:bool=skill.automatic or skill.trigger==SkillDefinition.Trigger.AUTO_SUPPORT
	if caster.team==0 and caster.character!=null:
		fallback=bool(GameSettings.support_modes.get(caster.character.persistent_id+":"+str(skill.id),fallback))
	return skill.supports_autocast() and bool(autocast.get(skill.id,fallback))
func set_autocast(skill: SkillDefinition, enabled: bool) -> bool:
	if skill == null or not skill.supports_autocast() or skill not in caster.available_skills() or not caster.alive(): return false
	autocast[skill.id] = enabled
	if caster.team==0 and caster.character!=null:
		GameSettings.set_support_mode(caster.character.persistent_id,skill.id,enabled)
	auto_scan_left = 0.0
	return true
func support_target(skill: SkillDefinition) -> TacticalUnit:
	var result: TacticalUnit
	var lowest: float = 1.0
	var mana: bool = skill.effect==SkillDefinition.Effect.SUPPLY
	for target: TacticalUnit in caster.director.units.values():
		if not target.alive() or target.team!=caster.team or target.position.distance_to(caster.position)>skill.range: continue
		# Mana transfer never targets its caster: prevent self-funded MP loops.
		if mana and target==caster: continue
		var maximum: float = target.vitals.max_mana if mana else target.vitals.max_health
		if maximum<=0: continue
		var ratio: float = (target.vitals.mana if mana else target.vitals.health)/maximum
		if ratio<lowest-0.000001:
			lowest = ratio
			result = target
	return result
func critical_attack(base: float) -> Dictionary:
	var power: float = base
	var critical: bool = false
	for skill: SkillDefinition in caster.available_skills():
		if skill.trigger != SkillDefinition.Trigger.ATTACK_HIT or skill.effect != SkillDefinition.Effect.CRITICAL or not available(skill):
			continue
		if caster.director.rng.randf() < skill.proc_chance:
			var result: Dictionary = skill.result(caster.stats_snapshot())
			if result["valid"] and caster.vitals.spend(skill.mana_cost):
				var multiplier: float = skill.critical_multiplier_min
				if skill.critical_multiplier_max>multiplier: multiplier = caster.director.rng.randf_range(multiplier,skill.critical_multiplier_max)
				power = float(result["value"])*multiplier
				critical = true
				cooldowns[skill.id] = skill.cooldown
				break
	return {"power":power, "critical":critical}

func on_basic_damage_landed(actual_damage: float, target: TacticalUnit=null) -> void:
	if actual_damage<=0 or not caster.alive(): return
	for skill: SkillDefinition in caster.available_skills():
		if skill.effect in [SkillDefinition.Effect.SUMMON,SkillDefinition.Effect.ATTACK_FLAME,SkillDefinition.Effect.SHOCKWAVE] and skill.trigger==SkillDefinition.Trigger.ATTACK_HIT:
			if not available(skill) or caster.director.rng.randf()>=skill.proc_chance: continue
			var point: Vector2=caster.position if skill.effect==SkillDefinition.Effect.SUMMON else target.position if target!=null else caster.position
			if caster.director.validate_skill_target(caster,skill,point,target.unit_id if target!=null else -1)!="": continue
			if caster.vitals.spend(skill.mana_cost): commit(skill,point,target.unit_id if target!=null else -1)
			continue
		if skill.effect!=SkillDefinition.Effect.LIFE_STEAL or skill.trigger!=SkillDefinition.Trigger.ATTACK_HIT or not available(skill): continue
		if caster.director.rng.randf() >= skill.proc_chance or not caster.vitals.spend(skill.mana_cost): continue
		var before: float = caster.vitals.health
		caster.vitals.heal(actual_damage*clampf(skill.life_steal_ratio,0.0,1.0))
		var restored: float = caster.vitals.health-before
		if restored>0: caster.director._damage_popup(caster,"吸血 +%d" % int(restored),Color(0.5,1.0,0.4))
		cooldowns[skill.id] = maxf(0,skill.cooldown)
		break
