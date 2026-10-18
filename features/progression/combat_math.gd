class_name CombatMath
extends RefCounted
enum Kind { PHYSICAL, MAGIC }
static func hit_chance(attacker: Dictionary, defender: Dictionary, rules: CombatStatRules, rng: RandomNumberGenerator) -> float:
	var accuracy: float = rng.randf_range(float(attacker["accuracy_min"]), float(attacker["accuracy_max"]))
	return clampf(rules.base_hit_chance + (accuracy - float(defender["accuracy"])) * rules.accuracy_chance_factor - float(defender["evasion"]), 0.05, 1.0)
static func mitigate(power: float, defender: Dictionary, armor: float, kind: Kind, rng: RandomNumberGenerator) -> float:
	if kind == Kind.MAGIC:
		return maxf(0, power) * (1 - clampf(float(defender["magic_resistance"]), 0, 0.9))
	var defense: float = rng.randf_range(float(defender["defense_min"]), float(defender["defense_max"]))
	return DamageFormula.mitigate(maxf(0, power - defense), armor)
