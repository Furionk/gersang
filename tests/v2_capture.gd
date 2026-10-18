extends Node
var game: GameDirector
func _ready() -> void:
	call_deferred("run")
func fresh() -> void:
	game.start_battle(Catalog.encounters()[0])
	while game.mode != &"battle":
		await get_tree().process_frame
	game.set_physics_process(false)
	game.camera.position = Iso.project(Vector2(640, 650))
	for unit: TacticalUnit in game.units.values():
		unit.vitals.max_health = 10000
		unit.vitals.health = 10000
func step(caster: TacticalUnit, seconds: float) -> void:
	for frame: int in int(seconds * 60):
		caster.tick(1.0 / 60)
		game._tick_projectiles(1.0 / 60)
		game._tick_effects(1.0 / 60)
		await get_tree().physics_frame
func save(name_text: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(TestArtifacts.output("v2","v2-" + name_text + "-preview.png"))
func find_skill(unit: TacticalUnit, id: StringName) -> SkillDefinition:
	for skill: SkillDefinition in unit.definition.skills:
		if skill.id == id:
			return skill
	return null
func run() -> void:
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	game.cinematic_camera = false
	while game.mode != &"world":
		await get_tree().process_frame
	await fresh()
	game.selection.select_ids([game.roster_ids[1]])
	await get_tree().process_frame
	await save("selected")
	game.selection.select_ids(game.roster_ids)
	await get_tree().process_frame
	await save("union")
	for spec: Array in [["quake", 0], ["blast", 1], ["wheel", 6], ["dragon", 3], ["summon", 2], ["ice_wall", 5], ["critical", 2]]:
		await fresh()
		var id: StringName = StringName(spec[0])
		var caster: TacticalUnit = game.get_unit(game.roster_ids[int(spec[1])])
		var enemy: TacticalUnit = game.get_unit(game.living_ids(1)[0])
		game.selection.select_ids([caster.unit_id])
		var point: Vector2 = caster.position + Vector2(80, 0)
		enemy.position = point
		if id == &"critical":
			caster.definition = caster.definition.duplicate(true) as UnitDefinition
			find_skill(caster, &"critical").proc_chance = 1
			caster.issue_command({"kind":"attack", "target":enemy.unit_id})
			await step(caster, 0.48)
		else:
			var skill: SkillDefinition = find_skill(caster, id)
			if id == &"summon":
				point = Vector2(330, 800)
			elif id == &"ice_wall":
				caster.position = Vector2(620, 950)
				point = Vector2(720, 930)
				enemy.position = Vector2(1000, 950)
				game.camera.position = Iso.project(Vector2(680, 830))
			elif id == &"dragon":
				point = caster.position + Vector2(1, 0)
				enemy.position = caster.position + Vector2(200, 0)
			caster.abilities.request(skill, point, enemy.unit_id if skill.target_mode == SkillDefinition.Target.ENEMY else -1)
			await step(caster, 0.65 if id == &"dragon" else 0.4)
		await save(String(id))
	await fresh()
	game.hud.show_settings()
	await get_tree().process_frame
	await save("settings")
	game.hud.close_windows()
	game.hud.show_sequence()
	await get_tree().process_frame
	await save("sequence")
	print("GERSANG_V2_VISUAL_OK")
	get_tree().quit()
