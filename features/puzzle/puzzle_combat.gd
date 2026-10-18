class_name PuzzleCombat
extends RefCounted
var friends: Array[Dictionary] = []
var enemies: Array[Dictionary] = []
var rules: PuzzleRules
var maximum_health: float = 0.0
var target: int = 0
var turn: int = 1

func setup(allies: Array[Dictionary], foes: Array[Dictionary], config: PuzzleRules, seed_value: int) -> void:
	friends = allies.duplicate(true)
	enemies = foes.duplicate(true)
	rules = config
	maximum_health = 0.0
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.seed = seed_value
	for ally: Dictionary in friends: maximum_health += ally.max_hp
	for enemy: Dictionary in enemies:
		var enemy_rules: PuzzleRules = enemy.get("rules",rules)
		enemy["attack_fraction"] = enemy_rules.enemy_attack_fraction
		enemy["cooldown_seconds"] = maxf(0.1,enemy_rules.enemy_cooldown_seconds)
		enemy.cooldown = random.randf_range(maxf(0.1,enemy_rules.enemy_initial_min_seconds),maxf(0.1,maxf(enemy_rules.enemy_initial_min_seconds,enemy_rules.enemy_initial_max_seconds)))

func health() -> float:
	var total: float = 0.0
	for ally: Dictionary in friends: total += ally.hp
	return total

func outcome() -> String:
	if health() <= 0.0: return "defeat"
	for enemy: Dictionary in enemies:
		if enemy.hp > 0.0: return ""
	return "victory"

func live_target() -> int:
	if target >= 0 and target < enemies.size() and enemies[target].hp > 0: return target
	for i: int in enemies.size():
		if enemies[i].hp > 0:
			target = i
			return i
	return -1

func distribute(amount: float, healing: bool) -> float:
	var remaining: float = maxf(0.0,amount)
	var applied: float = 0.0
	# Re-distribute overflow until every eligible member is capped or the pool is spent.
	for iteration: int in friends.size()+1:
		var eligible: Array[Dictionary] = []
		var weight: float = 0.0
		for ally: Dictionary in friends:
			if ally.hp > 0 and (not healing or ally.hp < ally.max_hp):
				eligible.append(ally)
				weight += ally.max_hp
		if eligible.is_empty() or remaining < 0.000001: break
		var used: float = 0.0
		for ally: Dictionary in eligible:
			var capacity: float = ally.max_hp-ally.hp if healing else ally.hp
			var value: float = minf(capacity,remaining*ally.max_hp/weight)
			ally.hp = clampf(ally.hp+value if healing else ally.hp-value,0.0,ally.max_hp)
			used += value
		remaining -= used
		applied += used
	return applied

func actions(groups: Array[Dictionary]) -> Array[Dictionary]:
	var multipliers: Array[float] = [0,0,0,0,0]
	for group: Dictionary in groups:
		multipliers[group.element] += 1.0+maxi(0,group.count-3)*rules.extra_orb_bonus
	var combo: float = 1.0+maxi(0,groups.size()-1)*rules.combo_bonus
	var result: Array[Dictionary] = []
	for i: int in friends.size():
		var ally: Dictionary = friends[i]
		if ally.hp > 0 and multipliers[ally.element] > 0:
			result.append({"kind":"attack","actor":i,"combos":groups.size(),"power":ally.attack*multipliers[ally.element]*combo})
	if multipliers[4] > 0:
		result.append({"kind":"heal","power":maximum_health*rules.heart_fraction*multipliers[4]*combo})
	return result

func apply_action(action: Dictionary) -> Dictionary:
	var event: Dictionary = action.duplicate()
	match action.kind:
		"attack":
			var index: int = live_target()
			if index < 0: return {}
			var ally: Dictionary = friends[action.actor]
			if ally.hp <= 0: return {}
			var foe: Dictionary = enemies[index]
			var damage: float = minf(foe.hp,action.power*PuzzleRules.affinity(ally.element,foe.element))
			foe.hp = maxf(0,foe.hp-damage)
			event.merge({"target":index,"amount":damage,"dead":foe.hp<=0})
		"heal": event.amount = distribute(action.power,true)
		"enemy_attack":
			var foe: Dictionary = enemies[action.actor]
			if foe.hp <= 0 or health() <= 0: return {}
			event.amount = distribute(maximum_health*foe.attack_fraction,false)
			foe.cooldown += foe.cooldown_seconds
	return event

# Resolve elapsed deadlines in chronological order, with stable queue order on ties.
func tick_enemies(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if delta <= 0 or not outcome().is_empty(): return events
	for foe: Dictionary in enemies:
		if foe.hp > 0: foe.cooldown -= delta
	while health() > 0:
		var due: int = -1
		for i: int in enemies.size():
			if enemies[i].hp > 0 and enemies[i].cooldown <= 0:
				if due < 0 or enemies[i].cooldown < enemies[due].cooldown: due = i
		if due < 0: break
		events.append(apply_action({"kind":"enemy_attack","actor":due}))
	return events
