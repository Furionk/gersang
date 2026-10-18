extends Node
var passed: int = 0
var failures: Array[String] = []
var game: GameDirector
var notices: int = 0
func check(ok: bool, text: String) -> void:
	if ok:
		passed += 1
		print("PASS | ",text)
	else:
		failures.append(text)
		push_error("FAIL | "+text)
func _ready() -> void:
	get_tree().create_timer(45).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func click(button: Control) -> void:
	var at: Vector2 = get_viewport().get_stretch_transform()*button.get_global_rect().get_center()
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = at
	get_viewport().push_input(motion,false)
	await get_tree().process_frame
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = at
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event,false)
	await get_tree().process_frame
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	get_viewport().push_input(event,false)
	await get_tree().process_frame
func capture(path: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.hud.next_refresh = 0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/world/"+path)
func run() -> void:
	LegacyPartyFixture.install()
	check(not PartyProgress.persistence_enabled,"POLISH-01 isolated progress")
	var record: CharacterRecord = PartyProgress.records[0]
	record.add_experience(CharacterRecord.CURVE.threshold(51))
	record.allocate("strength",100)
	record.allocate("intelligence",50)
	record.health = record.stats()["health"]
	record.mana = record.stats()["mana"]
	var before: Dictionary = record.serialize()
	record.changed.connect(func() -> void: notices+=1)
	check(record.reset_allocations()==150 and record.points()==200,"POLISH-02 respec refunds only spent points")
	check(notices==1 and record.reset_allocations()==0 and notices==1,"POLISH-02 atomic notification and empty reset no-op")
	check(record.level()==51 and record.experience==before["xp"] and record.bag==before["bag"] and record.equipment==before["equipment"],"POLISH-02 respec preserves level inventory and equipment")
	check(record.health<=record.stats()["health"] and record.mana<=record.stats()["mana"],"POLISH-02 lowered maximum clamps HP MP")
	var restored: CharacterRecord = CharacterRecord.new()
	restored.initialize(record.definition,record.persistent_id,false)
	check(restored.restore(record.serialize()) and restored.points()==200,"POLISH-02 reset record save round-trip")
	restored.allocate("strength",1)
	restored.health = 0
	check(restored.reset_allocations()==1 and restored.health==0,"POLISH-02 respec does not revive a dead character")
	LegacyPartyFixture.install()
	var summon: SkillDefinition = load("res://features/skills/data/summon.tres")
	var base: UnitDefinition = summon.effect_data.summon_definition as UnitDefinition
	var low: UnitDefinition = SummonScaling.resolve(summon.effect_data,{"agility":20})
	var high: UnitDefinition = SummonScaling.resolve(summon.effect_data,{"agility":100})
	check(low.damage==60 and high.damage==220,"POLISH-03 agility increases authored summon attack")
	check(low.accuracy==140 and high.accuracy==300,"POLISH-03 agility increases authored summon accuracy")
	check(base.damage==20 and base.accuracy==100 and low!=high,"POLISH-03 blueprint untouched and separate snapshots")
	var invalid: SkillEffectDefinition = summon.effect_data.duplicate(true)
	invalid.summon_attack_bonus_formula = "unknown/0"
	check(not SummonScaling.evaluate(invalid,{"agility":20})["valid"],"POLISH-03 bad summon scaling rejected")
	for name_text: String in ["beast","elite"]:
		var definition: UnitDefinition = load(UnitResourcePaths.canonical("res://features/units/data/%s.tres" % name_text))
		var texture: Texture2D = load(definition.sprite_path)
		var layout: SpriteSheetLayout = definition.sprite_layout
		check(layout.valid_for(Vector2i(texture.get_width(),texture.get_height())),"POLISH-04 valid 48-frame layout "+name_text)
		var frames: SpriteFrames = SpriteAtlas.frames(texture,layout)
		check(frames==SpriteAtlas.frames(texture,layout) and frames.get_animation_names().size()==40,"POLISH-04 shared frame cache "+name_text)
		for row: int in 8:
			var anchor: Vector2 = layout.source_pivots[SpriteAtlas.source_row(layout,row)*6]+SpriteAtlas.frame(texture,layout,row,0).margin.position
			check(anchor.is_equal_approx(layout.foot_point),"POLISH-04 stable foot pivot %s row %d" % [name_text,row])
			for column: int in 6:
				var frame: AtlasTexture = SpriteAtlas.frame(texture,layout,row,column)
				check(frame.filter_clip and frame.get_width()==224 and frame.get_height()==224,"POLISH-04 clipped constant canvas %s %d/%d" % [name_text,row,column])
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	game.select_world_slot(2)
	record = PartyProgress.selected()
	record.add_experience(CharacterRecord.CURVE.threshold(11))
	record.allocate("agility",40)
	game.hud.progression.show_stats()
	var ui: ProgressionPanels = game.hud.progression
	await click(ui.respec_button)
	check(ui.respec_panel.visible and record.allocated["agility"]==40,"POLISH-05 button opens confirmation, no early mutation")
	await capture("party-polish-confirm.png")
	await click(ui.respec_no)
	check(not ui.respec_panel.visible and record.allocated["agility"]==40,"POLISH-05 cancel preserves allocations")
	await click(ui.respec_button)
	await click(ui.respec_yes)
	check(record.points()==40 and record.allocated["agility"]==0 and ui.respec_button.disabled,"POLISH-05 native confirm resets selected mercenary")
	check(PartyProgress.records[0].level()==1,"POLISH-05 reset does not change protagonist")
	check(not game.reset_world_attributes(PartyProgress.records[0].persistent_id),"POLISH-05 stale selection cannot reset another character")
	await capture("party-polish-respec.png")
	game.hud.close_windows()
	game.select_world_slot(0)
	var hero_record: CharacterRecord = PartyProgress.selected()
	hero_record.add_experience(CharacterRecord.CURVE.threshold(2))
	hero_record.allocate("agility",4)
	var boosted_speed: float = game.world_hero.combat_stats["speed"]
	game.world_hero.vitals.health = 0
	check(game.reset_world_attributes(hero_record.persistent_id) and game.world_hero.combat_stats["speed"]<boosted_speed,"POLISH-02 live protagonist stats recalculate after reset")
	check(hero_record.health==0 and game.world_hero.vitals.health==0,"POLISH-02 button path does not revive a dead live actor")
	game.start_battle(Catalog.encounters()[0])
	while game.mode!=&"battle": await get_tree().process_frame
	var all_down: bool = true
	for unit: TacticalUnit in game.units.values():
		all_down = all_down and Iso.direction_index(unit.facing)==2 and unit.view.sprite.animation==&"idle_2"
	check(all_down,"POLISH-06 both armies enter facing camera/south row")
	check(not game.reset_world_attributes(record.persistent_id),"POLISH-05 respec rejected during battle")
	await capture("party-polish-entry.png")
	var caster: TacticalUnit = game.get_unit(game.roster_ids[2])
	caster.combat_stats["agility"] = 100.0
	caster.vitals.mana = 1000
	var invalid_skill: SkillDefinition = summon.duplicate(true)
	invalid_skill.effect_data.summon_attack_bonus_formula = "unknown/0"
	var mana_before: float = caster.vitals.mana
	check(game.validate_skill_target(caster,invalid_skill,caster.position,-1)!="" and caster.vitals.mana==mana_before,"POLISH-03 invalid scaling rejected before MP or commands")
	game.resolve_skill(caster,summon,caster.position+Vector2(150,80),-1)
	var spirit: TacticalUnit = game.get_unit(caster.abilities.active_summons[&"summon"])
	check(spirit.combat_stats["attack"]==220 and spirit.combat_stats["accuracy"]==360,"POLISH-03 actual summon receives derived attack and hit stats")
	caster.combat_stats["agility"] = 20
	check(spirit.combat_stats["attack"]==220,"POLISH-03 summon retains release snapshot")
	check(spirit.is_summon and spirit.summon_left==20 and game.roster_ids.size()==7,"POLISH-03 lifetime and capacity unchanged")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 2
	var target: Dictionary = caster.stats_snapshot()
	target["accuracy"] = 300
	target["evasion"] = 0.5
	var weak: Dictionary = spirit.combat_stats.duplicate()
	weak["accuracy_min"] = 160
	weak["accuracy_max"] = 160
	check(CombatMath.hit_chance(spirit.combat_stats,target,spirit.rules(),rng)>CombatMath.hit_chance(weak,target,spirit.rules(),rng),"POLISH-03 accuracy scaling improves actual hit probability")
	check(SkillDescription.calculation(summon,{"agility":100},{}).contains("198.0–242.0"),"POLISH-03 UI preview shares scaling calculation")
	await capture("party-polish-spirit.png")
	var report: Dictionary = {"engine":Engine.get_version_info()["string"],"passed":passed,"failed":failures.size(),"failures":failures,"rendered":DisplayServer.get_name()!="headless"}
	var file: FileAccess = FileAccess.open("res://artifacts/world/party-polish-%s-results.json" % ("render" if report["rendered"] else "headless"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("PARTY_POLISH_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
