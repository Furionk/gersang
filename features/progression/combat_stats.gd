class_name CombatStats
extends RefCounted
const DEFAULT_RULES: CombatStatRules = preload("res://features/progression/data/stat_rules.tres")
static func calculate(data: UnitDefinition, attributes: Dictionary, level: int, modifiers: Dictionary = {}) -> Dictionary:
	var r: CombatStatRules = data.stat_rules if data.stat_rules != null else DEFAULT_RULES
	var values: Dictionary = attributes.duplicate()
	for key: String in ["strength", "agility", "intelligence", "luck", "vitality"]:
		values[key] = maxf(0, float(attributes.get(key, 20)) + float(modifiers.get(key, 0)))
	values["level"] = level
	var strength: float = float(values["strength"]) - r.attribute_reference
	var agility: float = float(values["agility"]) - r.attribute_reference
	var intelligence: float = float(values["intelligence"]) - r.attribute_reference
	var luck: float = float(values["luck"]) - r.attribute_reference
	var growth: int = maxi(0, level - 1)
	var attack: float = maxf(0, data.damage + strength * r.attack_per_strength + growth * r.attack_per_level + float(modifiers.get("attack", 0)))
	var defense: float = maxf(0, data.defense + strength * r.defense_per_strength + growth * r.defense_per_level + float(modifiers.get("defense", 0)))
	var accuracy: float = maxf(1, data.accuracy + float(values["agility"]) * r.accuracy_per_agility + float(values["luck"]) * r.accuracy_per_luck + float(modifiers.get("accuracy", 0)))
	values.merge({"attack":attack, "attack_min":attack * (1 - r.attack_variance), "attack_max":attack * (1 + r.attack_variance),
		"defense":defense, "defense_min":defense * (1 - r.defense_variance), "defense_max":defense * (1 + r.defense_variance),
		"accuracy":accuracy, "accuracy_min":accuracy * (1 - r.accuracy_variance), "accuracy_max":accuracy * (1 + r.accuracy_variance),
		"health":maxf(1, data.max_health + strength * r.health_per_strength + growth * r.health_per_level + float(modifiers.get("health", 0))),
		"mana":maxf(0, data.max_mana + intelligence * r.mana_per_intelligence + growth * r.mana_per_level + float(modifiers.get("mana", 0))),
		"speed":maxf(10, data.speed * clampf(1 + agility * r.speed_per_agility, 0.2, 3.0) + float(modifiers.get("speed", 0))),
		"evasion":clampf(data.evasion + r.base_evasion + agility * r.evade_per_agility + luck * r.evade_per_luck + float(modifiers.get("evasion", 0)), 0, 0.8),
		"crit":clampf(r.base_crit + luck * r.crit_per_luck + float(modifiers.get("crit", 0)), 0, 1),
		"magic_resistance":clampf(data.magic_resistance + float(modifiers.get("magic_resistance", 0)), 0, 0.9)}, true)
	# Source weapon ranges are flat bonuses, not a fabricated symmetric variance.
	values["attack_min"] += float(modifiers.get("attack_min",0))
	values["attack_max"] += float(modifiers.get("attack_max",0))
	values["attack_min"] = maxf(0,values["attack_min"])
	values["attack_max"] = maxf(values["attack_min"],values["attack_max"])
	values["attack"] = (values["attack_min"]+values["attack_max"])*0.5
	if data.puzzle_monster != null:
		values["health"] = data.puzzle_monster.monster_health(level)
	return values
