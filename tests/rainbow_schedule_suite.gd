extends Node
var failed: int = 0
func check(value: bool, label: String) -> void:
	if not value: failed += 1
	print(("PASS | " if value else "FAIL | ") + label)
func _ready() -> void:
	var scheduler = preload("res://features/rainbow/attack_schedule.gd").new()
	var legal := func(_from: Vector2, to: Vector2, radius: float) -> bool: return Rect2(-500+radius,-500+radius,1000-radius*2,1000-radius*2).has_point(to)
	var trapped: Array[Dictionary] = [{"kind":"circle","center":Vector2.ZERO,"radius":1000.0,"inner":0.0,"warning":1.2,"fired":false}]
	check(not scheduler.can_escape(Vector2.ZERO,150,12,trapped,legal), "fully sealed future damage is rejected")
	var delayed: Array[Dictionary] = [{"kind":"circle","center":Vector2.ZERO,"radius":35.0,"inner":0.0,"warning":0.12,"fired":false}]
	check(not scheduler.can_escape(Vector2.ZERO,500,12,delayed,legal,0.2),"current action lock cannot be bypassed by escape search")
	var tier := RainbowBossTier.new()
	var random := RandomNumberGenerator.new()
	var accepted: int = 0
	for seed_value: int in 100:
		random.seed = seed_value
		var reservations: Array[Dictionary] = []
		for i: int in 4:
			reservations.append({"kind":["circle","ring","cone","sector"][random.randi_range(0,3)],"center":Vector2(random.randf_range(-220,220),random.randf_range(-220,220)),"radius":random.randf_range(100,250),"inner":65.0,"direction":Vector2.from_angle(random.randf()*TAU),"angle":0.9,"warning":1.2 + i*0.3,"fired":false})
		if not scheduler.can_escape(Vector2.ZERO,150,12,reservations,legal): continue
		accepted += 1
		var route: PackedVector2Array = scheduler.last_route
		var safe: bool = true
		for hazard: Dictionary in reservations:
			var step: int = mini(int(hazard.warning / scheduler.STEP), route.size()-2)
			var fraction: float = (hazard.warning-step*scheduler.STEP)/scheduler.STEP
			var point: Vector2 = route[step].lerp(route[step+1],clampf(fraction,0,1))
			if RainbowTempleMechanics.contains(hazard,point,12): safe = false
		check(safe, "accepted route survives timed combination seed %d" % seed_value)
	check(accepted > 50, "scheduler retains varied playable combinations")
	random.seed = tier.seed
	var sequence: Array[String] = []
	var previous: String = ""
	var repeats: int = 0
	for i: int in 100:
		var choice: String = tier.choose(random,previous,repeats)
		repeats = repeats+1 if choice == previous else 1
		previous = choice; sequence.append(choice)
		check(repeats <= 2, "weighted pool repetition bounded %d" % i)
	random.seed = tier.seed; previous = ""; repeats = 0
	var reproduced: Array[String] = []
	for i: int in 100:
		var choice: String = tier.choose(random,previous,repeats)
		repeats = repeats+1 if choice == previous else 1
		previous = choice; reproduced.append(choice)
	check(sequence == reproduced, "same seed reproduces attack sequence")
	print("RAINBOW_SCHEDULE_RESULT failed=",failed," accepted=",accepted," seeds=100")
	get_tree().quit(1 if failed else 0)
