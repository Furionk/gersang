extends Node
var game: GameDirector
var passed: int = 0
var failures: int = 0
func check(condition: bool, caption: String) -> void:
	if condition:
		passed += 1
		print("PASS | ",caption)
	else:
		failures += 1
		push_error("FAIL | "+caption)
func _ready() -> void:
	get_tree().create_timer(35).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func click(at: Vector2) -> void:
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion,true)
	await get_tree().process_frame
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event,true)
	await get_tree().process_frame
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	get_viewport().push_input(event,true)
	await get_tree().process_frame
func key(code: Key) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = code
	event.pressed = true
	get_viewport().push_input(event,true)
	await get_tree().process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	get_viewport().push_input(event,true)
	await get_tree().process_frame
func center(control: Control) -> Vector2:
	return control.get_global_rect().get_center()
func run() -> void:
	LegacyPartyFixture.install()
	check(not PartyProgress.persistence_enabled,"test boot is isolated from real player save")
	var curve: ExperienceCurve = CharacterRecord.CURVE
	check(curve.threshold(2)==20 and curve.threshold(50)==1094720 and curve.threshold(100)==18350220,"source XP milestones preserved")
	for level: int in range(2,101):
		check(curve.level_for(curve.threshold(level)-1)==level-1 and curve.level_for(curve.threshold(level))==level,"XP boundary Lv.%d" % level)
	var record: CharacterRecord = PartyProgress.records[0]
	check(record.add_experience(50)==2 and record.level()==3 and record.points()==8,"one reward can cross several levels")
	check(record.allocate("luck") and record.points()==7 and not record.allocate("unknown"),"valid stat allocation consumes exactly one point")
	record.add_experience(1000000000)
	check(record.level()==100 and record.experience==18350220,"level and XP stop at Lv.100")
	LegacyPartyFixture.install()
	record = PartyProgress.records[0]
	var original: Dictionary = record.stats()
	check(record.use_item(0) and record.stats()["strength"]==24 and record.stats()["attack"]>original["attack"],"equipped weapon modifies primary and derived attack")
	check(PartyProgress.records[1].stats()["strength"]==20 and record.definition.strength==20,"equipment and progression do not mutate shared definitions")
	check(record.unequip(&"weapon") and record.stats()["attack"]==original["attack"],"unequip removes exactly its modifier")
	var serialized: Dictionary = record.serialize()
	var restored: CharacterRecord = CharacterRecord.new()
	restored.initialize(record.definition,record.persistent_id,false)
	check(restored.restore(serialized) and restored.serialize()==serialized,"character inventory and stats round-trip")
	var invalid: Dictionary = serialized.duplicate(true)
	invalid["allocated"]["strength"] = 100
	check(not restored.restore(invalid),"invalid excess allocation rejected")
	invalid = serialized.duplicate(true)
	invalid["bag"][0]["item"] = &"unknown"
	invalid["bag"][0]["count"] = 1
	check(not restored.restore(invalid),"unknown inventory item rejected")
	var before: Array[Dictionary] = record.bag.duplicate(true)
	record.max_weight = 10000
	check(not record.add_item(&"material",400) and record.bag==before,"full bag rejection is transactional")
	record.max_weight = 80
	check(not record.add_item(&"material",1000) and record.bag==before,"weight rejection does not partially add")
	record.health = 10
	check(record.use_item(4) and record.health==70 and record.bag[4]["count"]==2,"food heals selected record and consumes one")
	record.health = float(record.stats()["health"])
	check(not record.use_item(4) and record.bag[4]["count"]==2,"full health does not consume food")
	var r: CombatStatRules = CombatStats.DEFAULT_RULES
	var attrs: Dictionary = {"strength":30,"agility":30,"intelligence":30,"luck":30,"vitality":20}
	var improved: Dictionary = CombatStats.calculate(record.definition,attrs,1)
	check(improved["health"]>original["health"] and improved["attack"]>original["attack"] and improved["defense"]>original["defense"],"strength derives attack defense and HP")
	check(improved["speed"]>original["speed"] and improved["accuracy"]>original["accuracy"] and improved["evasion"]>original["evasion"],"agility derives speed accuracy and evasion")
	check(improved["mana"]>original["mana"] and improved["crit"]>original["crit"],"intelligence and luck affect mana and crit")
	check(DamageFormula.evaluate("幸運*2+敏捷",improved)["value"]==90,"Chinese luck participates in skill formula")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42
	var defender: Dictionary = original.duplicate()
	defender["defense_min"] = 10.0
	defender["defense_max"] = 10.0
	defender["magic_resistance"] = 0.4
	check(is_equal_approx(CombatMath.mitigate(100,defender,0.25,CombatMath.Kind.PHYSICAL,rng),67.5),"physical defense range then armor applied once")
	check(is_equal_approx(CombatMath.mitigate(100,defender,0.25,CombatMath.Kind.MAGIC,rng),60),"magic resistance replaces physical defense for spells")
	check(CombatMath.mitigate(2,defender,0,CombatMath.Kind.PHYSICAL,rng)==0,"defense cannot produce negative damage")
	var accurate: Dictionary = original.duplicate()
	accurate["accuracy_min"] = 100000.0
	accurate["accuracy_max"] = 100000.0
	check(CombatMath.hit_chance(accurate,defender,r,rng)==1,"high accuracy clamps to guaranteed hit")
	defender["evasion"] = 0.8
	check(CombatMath.hit_chance(original,defender,r,rng)<0.25,"evasion opposes attacker accuracy")
	# Real versioned file; unique test path never replaces player's progress.
	PartyProgress.save_path = "user://progression-regression-%d.dat" % Time.get_ticks_usec()
	PartyProgress.persistence_enabled = true
	check(PartyProgress.save_party(),"atomic versioned save succeeds")
	PartyProgress.records[1].add_experience(50)
	check(FileAccess.file_exists(PartyProgress.save_path+".bak"),"previous save retained as backup")
	LegacyPartyFixture.install()
	check(PartyProgress.load_party() and PartyProgress.records[1].level()==3,"restart restores XP and independent levels")
	var bad: FileAccess = FileAccess.open(PartyProgress.save_path,FileAccess.WRITE)
	bad.store_var({"version":999,"party":[]},false)
	bad.close()
	var hash: String = FileAccess.get_sha256(PartyProgress.save_path)
	check(not PartyProgress.load_party() and PartyProgress.save_protected and not PartyProgress.save_party() and FileAccess.get_sha256(PartyProgress.save_path)==hash,"future-version save preserved and cannot be silently overwritten")
	PartyProgress.persistence_enabled = false
	PartyProgress.save_protected = false
	PartyProgress.last_error = ""
	LegacyPartyFixture.install()
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode!=&"world":
		await get_tree().process_frame
	game.set_physics_process(false)
	await click(center(game.hud.world_hud.roster_buttons[2]))
	check(PartyProgress.selected_slot==2,"world portrait selects non-hero mercenary")
	await key(KEY_S)
	check(game.hud.progression.stat_panel.visible and game.hud.progression.stat_title.text.contains("火銃手"),"S opens selected mercenary stats on left")
	await click(Vector2(200,300))
	check(game.world_hero.active.is_empty(),"stats GUI click cannot issue world movement")
	PartyProgress.selected().add_experience(20)
	await click(center(game.hud.progression.plus_buttons["strength"]))
	check(PartyProgress.selected().allocated["strength"]==1 and PartyProgress.selected().points()==3,"native plus button allocates selected mercenary stat")
	await key(KEY_I)
	check(game.hud.progression.inventory_panel.visible and not game.hud.progression.stat_panel.visible,"I switches to inventory without overlapping stats")
	await click(center(game.hud.progression.bag_buttons[0]))
	check(PartyProgress.selected().equipment[&"weapon"]==&"blade","native bag button equips weapon")
	await click(center(game.hud.progression.equipment_buttons[&"weapon"]))
	check(PartyProgress.selected().equipment[&"weapon"]==&"","native equipment button unequips weapon")
	await key(KEY_S)
	check(game.hud.progression.stat_panel.visible and not game.hud.progression.inventory_panel.visible,"S switches back to stats without a second window")
	await key(KEY_ESCAPE)
	check(not game.hud.progression.inventory_panel.visible and not game.hud.is_modal_open(),"Esc closes sheets before world menu")
	await key(KEY_5)
	check(PartyProgress.selected_slot==4,"world number key selects mercenary")
	game.start_battle(Catalog.encounters()[0])
	while game.mode!=&"battle":
		await get_tree().process_frame
	game.set_physics_process(false)
	var guard: TacticalUnit = game.get_unit(game.roster_ids[1])
	game.selection.select_ids([guard.unit_id])
	GameSettings._bind("skill_blast",KEY_I)
	GameSettings._bind("command_stop",KEY_S)
	await key(KEY_I)
	check(guard.casts==0 and guard.active.get("kind")=="cast" and game.selection.armed_skill_id==&"","D17 battle I directly orders self blast instead of inventory")
	guard.tick(1.0/60)
	check(guard.casts==1 and not game.hud.progression.inventory_panel.visible,"D17 battle I casts blast on fixed tick without left confirmation")
	await key(KEY_S)
	check(guard.active.is_empty() and not game.hud.progression.stat_panel.visible,"battle S still stops instead of stats")
	var expected: int = 0
	for id: int in game.living_ids(1):
		var enemy: TacticalUnit = game.get_unit(id)
		expected += enemy.definition.experience_reward
		enemy.vitals.damage(999999)
	game.finish_battle("victory")
	var awarded: int = 0
	for member: CharacterRecord in PartyProgress.records:
		awarded += member.experience
	check(awarded==expected+20,"victory XP distributed without loss plus previous XP")
	game.finish_battle("victory")
	var twice: int = 0
	for member: CharacterRecord in PartyProgress.records:
		twice += member.experience
	check(twice==awarded,"victory cannot award twice")
	game.start_world()
	while game.mode!=&"world":
		await get_tree().process_frame
	check(PartyProgress.records[0].level()>1 and game.world_hero.stats_snapshot()["level"]==PartyProgress.records[0].level(),"hero level persists into world actor stats")
	var attacker: TacticalUnit = game.world_hero
	attacker.definition = attacker.definition.duplicate(true) as UnitDefinition
	attacker.definition.stat_rules = CombatStats.DEFAULT_RULES.duplicate() as CombatStatRules
	attacker.definition.stat_rules.attack_variance = 0
	attacker.definition.stat_rules.base_hit_chance = 1
	attacker.definition.stat_rules.accuracy_chance_factor = 0
	attacker.combat_stats["crit"] = 1.0
	var target: TacticalUnit = game.spawn_unit(Catalog.enemy(0),1,Vector2(1000,900),false)
	target.vitals.armor = 0
	target.combat_stats["evasion"] = 0.0
	var hp: float = target.vitals.health
	game._basic_hit(attacker,target,10)
	check(is_equal_approx(hp-target.vitals.health,20),"natural critical 100 percent doubles actual damage")
	attacker.combat_stats["crit"] = 0.0
	hp = target.vitals.health
	game._basic_hit(attacker,target,10)
	check(is_equal_approx(hp-target.vitals.health,10),"natural critical zero percent keeps normal damage")
	attacker.definition.stat_rules.attack_variance = 0.1
	var observed: Array[float] = []
	for i: int in 20:
		hp = target.vitals.health
		game._basic_hit(attacker,target,1)
		observed.append(hp-target.vitals.health)
	var in_range: bool = observed.all(func(damage: float) -> bool: return damage>=0.899 and damage<=1.101)
	check(in_range and observed.max()-observed.min()>0.01,"actual attacks vary within configured range")
	attacker.definition.stat_rules.base_hit_chance = 0
	target.combat_stats["evasion"] = 0.8
	var misses: int = 0
	for i: int in 20:
		hp = target.vitals.health
		game._basic_hit(attacker,target,1)
		if hp==target.vitals.health:
			misses += 1
	check(misses>10,"opposed miss chance actually prevents HP damage")
	target.vitals.health = 10000
	target.vitals.armor = 0.9
	target.combat_stats["defense_min"] = 40.0
	target.combat_stats["defense_max"] = 40.0
	target.combat_stats["magic_resistance"] = 0.5
	var lightning: SkillDefinition = load("res://features/skills/data/lightning.tres") as SkillDefinition
	hp = target.vitals.health
	game.resolve_skill(attacker,lightning,target.position,-1)
	check(is_equal_approx(hp-target.vitals.health,26),"instant lightning uses magic resistance instead of physical defenses")
	var dragon: SkillDefinition = load("res://features/skills/data/dragon.tres") as SkillDefinition
	target.position = attacker.position+Vector2(100,0)
	hp = target.vitals.health
	game.resolve_skill(attacker,dragon,target.position,-1)
	game._tick_effects(0.4)
	check(is_equal_approx(hp-target.vitals.health,10),"persistent dragon ticks use the same magic-resistance pipeline")
	print("GERSANG_PROGRESSION_%s | passed=%d failed=%d" % ["PASS" if failures==0 else "FAIL",passed,failures])
	get_tree().quit(0 if failures==0 else 1)
