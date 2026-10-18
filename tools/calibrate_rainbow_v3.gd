extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var marker := "res://artifacts/rainbow-overhaul/balance-v3.json"
	if FileAccess.file_exists(marker): push_error("Calibration already applied; refusing multiplication twice."); quit(1); return
	var report: Array[Dictionary] = []
	for tier: int in 4:
		var level: int = [25,50,75,90][tier]
		var measurement: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://artifacts/rainbow-overhaul/dps-%d.json" % level))
		assert(int(measurement.members) == 10 and float(measurement.seconds) > 59)
		for species: String in ["fire_dragon","lava_priest"]:
			var dragon: bool = species == "fire_dragon"
			var id: String = species if tier == 0 else species + "_tier_%d" % tier
			var unit: UnitDefinition = load("res://features/units/data/monsters/%s.tres" % id)
			var seconds: float = [120,165,240,330][tier] if dragon else [90,135,180,270][tier]
			var uptime: float = [1.0,0.85,0.7,0.65][tier]
			var count: int = 1 if dragon else 1 << tier
			var target_hp: float = roundf(float(measurement.dps) * seconds * uptime / count)
			var resolved: Dictionary = PartyBuilder.resolve_member(unit,level,"calibration")
			unit.max_health = maxf(1,unit.max_health + target_hp - float(resolved.resolved_stats.health))
			unit.balance_revision += 1
			assert(ResourceSaver.save(unit,unit.resource_path) == OK)
			var enemy: RainbowEnemyDefinition = load("res://features/rainbow/data/enemies/%s.tres" % id)
			enemy.boss_tier = load("res://features/rainbow/data/dragon_tier_%d.tres" % tier)
			enemy.special_power = ([100,125,155,190][tier] if dragon else [85,95,110,125][tier])
			if not dragon: enemy.special_interval = [5.5,4.8,4.0,3.4][tier]
			assert(ResourceSaver.save(enemy,enemy.resource_path) == OK)
			report.append({"id":id,"recommended_level":level,"hp_per_member":target_hp,"count":count,"measured_baseline_dps":measurement.dps,"assumed_uptime":uptime,"target_seconds":seconds,"status":"initial estimate; tier-specific natural combat validation pending"})
	for id: String in ["rainbow_slime","lava_beast"]:
		var unit: UnitDefinition = load("res://features/units/data/monsters/%s.tres" % id)
		unit.max_health *= 1.6; unit.damage *= 1.25; unit.speed *= 1.1
		unit.balance_revision += 1
		assert(ResourceSaver.save(unit,unit.resource_path) == OK)
	var file := FileAccess.open(marker,FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("RAINBOW_BALANCE_AUTHORED from four measured ten-member benchmarks; human/tier timing acceptance pending")
	quit()
