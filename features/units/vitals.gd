class_name UnitVitals
extends Node
signal changed
signal died
var max_health: float = 1.0
var health: float = 1.0
var max_mana: float = 0.0
var mana: float = 0.0
var armor: float = 0.0
func initialize(definition: UnitDefinition) -> void:
	max_health = definition.max_health
	health = max_health
	max_mana = definition.max_mana
	mana = max_mana
	armor = definition.armor
func damage(amount: float) -> void:
	damage_resolved(DamageFormula.mitigate(amount, armor))
func damage_resolved(amount: float) -> void:
	if health <= 0.0 or amount <= 0.0:
		return
	health = maxf(0.0, health - amount)
	changed.emit()
	if health <= 0.0:
		died.emit()
func spend(amount: float) -> bool:
	if health <= 0.0 or mana + 0.001 < amount:
		return false
	mana = maxf(0.0, mana - amount)
	changed.emit()
	return true
func heal(amount: float) -> void:
	if health > 0.0:
		health = minf(max_health, health + amount)
		changed.emit()
func restore(amount: float) -> void:
	if health > 0.0:
		mana = minf(max_mana, mana + amount)
		changed.emit()

func recover(health_amount: float, mana_amount: float, allow_revive: bool) -> bool:
	if health <= 0 and not allow_revive: return false
	var before_hp: float = health
	var before_mp: float = mana
	health = minf(max_health,maxf(0,health)+maxf(0,health_amount))
	mana = minf(max_mana,mana+maxf(0,mana_amount))
	if health != before_hp or mana != before_mp:
		changed.emit()
		return true
	return false
func regenerate(delta: float, rate: float) -> void:
	if health > 0.0:
		mana = minf(max_mana, mana + rate * delta)
