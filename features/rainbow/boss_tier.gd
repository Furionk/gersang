class_name RainbowBossTier
extends Resource
@export_range(0,3) var tier: int = 0
@export var recommended_level: int = 25
@export var display_name: String = "簡單"
@export var interval: float = 4.5
@export var attack_pool: PackedStringArray = PackedStringArray(["breath","rain","ring"])
@export var weights: PackedFloat32Array = PackedFloat32Array([3,2,2])
@export_range(1,3) var maximum_repeats: int = 2
@export var seed: int = 55047
@export var transition_warning: float = 1.2

func choose(rng: RandomNumberGenerator, previous: String, repeats: int) -> String:
	var total: float = 0
	for i: int in attack_pool.size():
		if attack_pool[i] != previous or repeats < maximum_repeats: total += weights[i] if i < weights.size() else 1
	if total <= 0: return attack_pool[0] if not attack_pool.is_empty() else "breath"
	var draw: float = rng.randf() * total
	for i: int in attack_pool.size():
		if attack_pool[i] == previous and repeats >= maximum_repeats: continue
		draw -= weights[i] if i < weights.size() else 1
		if draw <= 0: return attack_pool[i]
	return attack_pool[-1]
