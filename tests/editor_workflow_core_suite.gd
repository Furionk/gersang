extends Node
var passed: int = 0
var failed: int = 0
func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1
func _ready() -> void: call_deferred("run")
func run() -> void:
	var old_path: String = GameSettings.settings_path
	var old_overrides: Dictionary = GameSettings.key_overrides.duplicate()
	GameSettings.settings_path="user://editor-workflow-key-test.cfg"
	var cfg: ConfigFile = ConfigFile.new()
	cfg.set_value("keys","skill_blast",KEY_I) # old generated default, not an explicit UI remap
	cfg.set_value("other","preserved",123)
	check(cfg.save(GameSettings.settings_path)==OK,"isolated old settings fixture")
	GameSettings.load_settings()
	var blast: SkillDefinition = load("res://features/skills/data/blast.tres")
	GameSettings.register_skill(blast)
	check(GameSettings.bindings.skill_blast==blast.default_key,"resource key overrides hardcoded old default")
	var custom: SkillDefinition = blast.duplicate(true)
	custom.default_key=KEY_K
	GameSettings.register_skill(custom)
	check(GameSettings.bindings.skill_blast==KEY_K,"resource edits refresh an existing registered action")
	check(GameSettings.rebind("skill_blast",KEY_J),"player can explicitly override key")
	custom.default_key=KEY_L; GameSettings.register_skill(custom)
	check(GameSettings.bindings.skill_blast==KEY_J,"explicit player override retained")
	GameSettings.load_settings(); GameSettings.register_skill(custom)
	check(GameSettings.bindings.skill_blast==KEY_J,"explicit override persists across reload")
	GameSettings.reset_skill_binding("skill_blast")
	check(GameSettings.bindings.skill_blast==KEY_L,"follow-resource clears only this override")
	cfg=ConfigFile.new(); cfg.load(GameSettings.settings_path)
	check(not cfg.has_section_key("keys","skill_blast") and cfg.get_value("other","preserved")==123,"defaults are not saved as overrides; unrelated settings retained")
	GameSettings.settings_path=old_path
	GameSettings.key_overrides=old_overrides
	for definition: UnitDefinition in Catalog.party():
		for skill: SkillDefinition in definition.skills: GameSettings.register_skill(skill)
	var game: GameDirector = load("res://main.tscn").instantiate()
	add_child(game); game.audio.muted=true
	while game.mode!=&"world": await get_tree().process_frame
	if DisplayServer.get_name()!="headless": await RenderingServer.frame_post_draw
	var ready_positions: Array[Vector2] = []
	game.mode_changed.connect(func(_mode: StringName) -> void: ready_positions.append(game.camera.position))
	game.start_battle(Catalog.encounters()[0])
	check(game.mode==&"loading" and not game.render_root.visible and game.transition_cover.shown,"new battle stays hidden while camera/actors load")
	if DisplayServer.get_name()!="headless": check(game.transition_cover.frame.texture!=null,"real rendered last-ready frame captured during loading")
	while game.mode!=&"battle": await get_tree().process_frame
	check(game.render_root.visible and not game.transition_cover.shown,"battle revealed only after staging")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/editor-workflow-2026-10-11/battle-ready.png")
	var selected: TacticalUnit = game.get_unit(game.roster_ids[1])
	game.selection.select_ids([selected.unit_id])
	var event: InputEventKey = InputEventKey.new()
	event.pressed=true; event.physical_keycode=blast.default_key
	var mana: float = selected.vitals.mana
	var skill_ids: Array = []
	for skill: SkillDefinition in selected.available_skills(): skill_ids.append(String(skill.id))
	print("HOTKEY_TRACE binding=",GameSettings.bindings.skill_blast," default=",blast.default_key," owned=",skill_ids," modal=",game.hud.is_modal_open())
	get_viewport().push_input(event,false)
	await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().process_frame
	print("HOTKEY_RESULT mana=",mana," -> ",selected.vitals.mana," error=",selected.abilities.last_error)
	check(selected.vitals.mana<mana,"actual resource hotkey casts selected immediate blast")
	var mage: TacticalUnit = game.get_unit(game.roster_ids[3])
	game.selection.select_ids([selected.unit_id,mage.unit_id])
	var messages: Array[String] = []
	game.message.connect(func(value: String) -> void: messages.append(value))
	if blast.default_key==int(GameSettings.bindings.get("skill_lightning",0)):
		get_viewport().push_input(event,false); await get_tree().process_frame
		check(messages.any(func(value: String) -> bool: return value.contains("快捷鍵衝突")),"ambiguous selected shortcuts get explicit UX")
	game.finish_battle("retreat")
	game.start_world()
	check(not game.render_root.visible and game.transition_cover.shown,"return world stays covered until camera ready")
	while game.mode!=&"world": await get_tree().process_frame
	check(game.camera.position.is_equal_approx(Iso.project(game.world_return)+Vector2(130,0)) and game.render_root.visible and not game.transition_cover.shown,"first world reveal uses correct camera")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/editor-workflow-2026-10-11/world-ready.png")
	game.queue_free(); await get_tree().process_frame
	print("EDITOR_WORKFLOW_CORE_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
