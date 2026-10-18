class_name StatusController
extends Node
signal changed
var slows: Dictionary = {}
var buffs: Dictionary = {}
var stealth_left: float = 0.0
var stealth_speed: float = 1.0
var reveal_bonus: float = 0.0
func apply_buff(key: StringName, data: SkillEffectDefinition, duration: float) -> void:
	buffs[key] = {"remaining":duration,"attack":data.attack_multiplier,"haste":data.attack_speed_multiplier,"range":data.attack_range_bonus,"bonus":data.attack_bonus,"speed":data.movement_multiplier}
	changed.emit()
func apply_stealth(duration: float, speed: float, bonus: float) -> void:
	stealth_left=maxf(0,duration); stealth_speed=speed; reveal_bonus=bonus
	changed.emit()
func hidden() -> bool: return stealth_left>0
func reveal(for_attack: bool = false) -> float:
	var bonus: float = reveal_bonus if for_attack and hidden() else 0.0
	stealth_left=0; reveal_bonus=0; stealth_speed=1
	changed.emit()
	return bonus
func buff_product(field: String) -> float:
	var value: float=1.0
	for entry: Dictionary in buffs.values(): value*=float(entry.get(field,1.0))
	return value
func buff_sum(field: String) -> float:
	var value: float=0.0
	for entry: Dictionary in buffs.values(): value+=float(entry.get(field,0.0))
	return value
func apply_slow(key: StringName, factor: float, duration: float) -> void:
	slows[key] = {"factor":clampf(factor, 0.05, 1.0), "remaining":maxf(0, duration)}
	changed.emit()
func tick(delta: float) -> void:
	if stealth_left>0:
		stealth_left=maxf(0,stealth_left-delta)
		if stealth_left==0: reveal(false)
	for key: StringName in buffs.keys():
		buffs[key]["remaining"]-=delta
		if buffs[key]["remaining"]<=0: buffs.erase(key); changed.emit()
	for key: StringName in slows.keys():
		slows[key]["remaining"] = float(slows[key]["remaining"]) - delta
		if float(slows[key]["remaining"]) <= 0:
			slows.erase(key)
			changed.emit()
func speed_multiplier() -> float:
	var result: float = 1.0
	for entry: Dictionary in slows.values():
		result = minf(result, float(entry["factor"]))
	return result*buff_product("speed")*(stealth_speed if hidden() else 1.0)
func clear() -> void:
	slows.clear()
	buffs.clear()
	stealth_left=0; reveal_bonus=0; stealth_speed=1
	changed.emit()
