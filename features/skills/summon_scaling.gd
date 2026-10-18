class_name SummonScaling
extends RefCounted
static func evaluate(data: SkillEffectDefinition, snapshot: Dictionary) -> Dictionary:
	if data==null or not data.summon_definition is UnitDefinition: return {"valid":false,"error":"召喚模板無效"}
	var attack: Dictionary = DamageFormula.evaluate(data.summon_attack_bonus_formula,snapshot)
	var accuracy: Dictionary = DamageFormula.evaluate(data.summon_accuracy_bonus_formula,snapshot)
	var intelligence: Dictionary = DamageFormula.evaluate(data.summon_intelligence_bonus_formula,snapshot)
	var health: Dictionary=DamageFormula.evaluate(data.summon_health_bonus_formula,snapshot)
	var defense: Dictionary=DamageFormula.evaluate(data.summon_defense_bonus_formula,snapshot)
	if not attack["valid"]: return {"valid":false,"error":"箭魂攻擊加成："+str(attack["error"])}
	if not accuracy["valid"]: return {"valid":false,"error":"箭魂命中加成："+str(accuracy["error"])}
	if not intelligence["valid"]: return {"valid":false,"error":"召喚智力加成："+str(intelligence["error"])}
	if not health.valid: return {"valid":false,"error":"召喚體力加成："+str(health.error)}
	if not defense.valid: return {"valid":false,"error":"召喚防禦加成："+str(defense.error)}
	return {"valid":true,"error":"","attack_bonus":attack["value"],"accuracy_bonus":accuracy["value"],"intelligence_bonus":intelligence["value"],"health_bonus":maxf(0,health.value),"defense_bonus":maxf(0,defense.value)}
static func resolve(data: SkillEffectDefinition, snapshot: Dictionary) -> UnitDefinition:
	var result: Dictionary = evaluate(data,snapshot)
	if not result["valid"]: return null
	var local: UnitDefinition = data.summon_definition.duplicate(true) as UnitDefinition
	local.damage += float(result["attack_bonus"])
	local.accuracy += float(result["accuracy_bonus"])
	local.intelligence += float(result["intelligence_bonus"])
	local.max_health+=float(result.health_bonus)
	local.defense+=float(result.defense_bonus)
	local.controllable = data.summon_controllable
	return local
static func preview_stats(data: SkillEffectDefinition, snapshot: Dictionary) -> Dictionary:
	var local: UnitDefinition = resolve(data,snapshot)
	if local==null: return {}
	return CombatStats.calculate(local,{"strength":local.strength,"agility":local.agility,"intelligence":local.intelligence,"luck":local.luck,"vitality":local.vitality},local.level)
