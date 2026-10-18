extends Node
var game: GameDirector
var passed: int = 0
var failures: Array[String] = []
var checks: Array[Dictionary] = []
func check(ok: bool, caption: String) -> void:
	checks.append({"test":caption,"pass":ok})
	if ok:
		passed += 1
		print("PASS | ",caption)
	else:
		failures.append(caption)
		push_error("FAIL | "+caption)
func _ready() -> void:
	get_tree().create_timer(45).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func key(code: Key, echo: bool = false, ctrl: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	event.echo = echo
	event.ctrl_pressed = ctrl
	get_viewport().push_input(event,true)
	await get_tree().process_frame
	event = event.duplicate() as InputEventKey
	event.pressed = false
	get_viewport().push_input(event,true)
	await get_tree().process_frame
func click(at: Vector2, button: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var point: Vector2 = get_viewport().get_stretch_transform()*at
	var motion: InputEventMouseMotion = InputEventMouseMotion.new()
	motion.position = point
	get_viewport().push_input(motion,false)
	await get_tree().process_frame
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = point
	event.button_index = button
	event.pressed = true
	get_viewport().push_input(event,false)
	await get_tree().process_frame
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	get_viewport().push_input(event,false)
	await get_tree().process_frame
func screen(unit: TacticalUnit) -> Vector2:
	return game.get_canvas_transform()*(Iso.project(unit.position)+Vector2(0,-35))
func tick(unit: TacticalUnit, frames: int = 1) -> void:
	for frame: int in frames: unit.tick(1.0/60)
func ready(unit: TacticalUnit) -> void:
	unit.issue_command({"kind":"stop"})
	unit.vitals.max_mana = 10000
	unit.vitals.mana = 10000
	unit.cooldowns.clear()
func capture(name_text: String) -> void:
	if DisplayServer.get_name()=="headless": return
	game.hud.next_refresh = 0
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/world/combat-ux-%s.png" % name_text)
func run() -> void:
	LegacyPartyFixture.install()
	check(not PartyProgress.persistence_enabled,"UX-01 isolated saves")
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode!=&"world": await get_tree().process_frame
	game.cursor_guard.set_process(false)
	game.cursor_guard.focused = true
	var world_at: Vector2 = game.world_context.state["player"]["position"]
	await key(KEY_F1)
	check(game.cursor_guard.enabled and game.cursor_guard.confinement_active,"UX-02 F1 also confines on the world map")
	check(game.world_context.state["player"]["position"]==world_at,"UX-02 world F1 does not change movement position")
	game.start_battle(Catalog.encounters()[0])
	while game.mode!=&"battle": await get_tree().process_frame
	game.cursor_guard.sync()
	check(game.cursor_guard.enabled and game.cursor_guard.confinement_active,"UX-02 world-to-battle transition preserves lock preference")
	await key(KEY_F1)
	check(not game.cursor_guard.enabled,"UX-02 world lock can be released in battle")
	game.set_physics_process(false)
	game.cinematic_camera = false
	game.camera.position = Iso.project(Vector2(600,600))
	game.camera.force_update_scroll()
	var hero: TacticalUnit = game.get_unit(game.roster_ids[0])
	var guard: TacticalUnit = game.get_unit(game.roster_ids[1])
	var mage: TacticalUnit = game.get_unit(game.roster_ids[3])
	var healer: TacticalUnit = game.get_unit(game.roster_ids[4])
	var supplier: TacticalUnit = game.get_unit(game.roster_ids[5])
	var controller: TacticalUnit = game.get_unit(game.roster_ids[6])
	var enemy: TacticalUnit = game.get_unit(game.living_ids(1)[0])
	for unit: TacticalUnit in game.units.values():
		ready(unit)
		unit.vitals.max_health = 10000
		unit.vitals.health = 10000
		unit.position = Vector2(1000,1000)+Vector2(unit.unit_id*55,0)
		for skill: SkillDefinition in unit.available_skills(): check(skill.cooldown==0,"UX-03 zero authored cooldown "+str(skill.id))
	mage.position = Vector2(600,600)
	guard.position = Vector2(400,600)
	hero.position = Vector2(590,480)
	healer.position = Vector2(450,500)
	supplier.position = Vector2(450,660)
	controller.position = Vector2(550,750)
	enemy.position = Vector2(710,600)
	var heal: SkillDefinition = healer.available_skills()[0]
	var supply: SkillDefinition = supplier.available_skills()[0]
	healer.abilities.set_autocast(heal,false)
	for frame: int in 5: await get_tree().process_frame
	game.selection.select_ids([mage.unit_id])
	var before: int = mage.casts
	await key(KEY_R)
	tick(mage)
	check(mage.casts==before and game.selection.armed_skill_id==&"dragon","UX-04 R prepares but never casts")
	await click(screen(enemy))
	tick(mage)
	check(mage.casts==before+1 and game.selection.armed_skill_id==&"","UX-04 first left click releases once and clears aim")
	check(mage.cooldowns.get(&"dragon",-1)==0,"UX-03 no hidden repeat-interval cooldown")
	await key(KEY_R)
	tick(mage)
	check(mage.casts==before+1,"UX-04 second R requires a new left click")
	await click(game.get_canvas_transform()*Iso.project(Vector2(660,680)))
	tick(mage)
	check(mage.casts==before+2,"UX-04 R-click R-click casts twice without waiting")
	GameSettings.profile.held_repeat_enabled = true
	GameSettings.profile.reserved_repeat_enabled = true
	game.selection.repeat_target[mage.unit_id] = {"skill":mage.available_skills()[0],"point":enemy.position,"target":-1}
	Input.action_press("skill_dragon")
	for frame: int in 60:
		tick(mage)
		game.selection.tick()
	Input.action_release("skill_dragon")
	check(mage.casts==before+2 and game.selection.repeat_target.is_empty(),"UX-05 held keys and old profiles cannot reuse a target")
	await key(KEY_R,true)
	check(game.selection.armed_skill_id==&"","UX-05 key echo never arms or casts")
	await key(KEY_R,false,true)
	await click(screen(enemy))
	tick(mage,60)
	check(mage.casts==before+3 and mage.repeat_command.is_empty(),"UX-05 Ctrl-click still casts only once")
	game.selection.select_ids([guard.unit_id])
	before = guard.casts
	await key(int(GameSettings.bindings["skill_blast"]) as Key)
	tick(guard)
	check(guard.casts==before+1 and game.selection.armed==&"" and game.selection.preview_kind()==&"none","D17 blast hotkey immediately casts without aiming")
	await click(Vector2(950,400))
	tick(guard)
	check(guard.casts==before+1,"D17 later ground click cannot duplicate instant blast")
	for effect: BattleSkillEffect in game.effects: effect.finish()
	game.effects.clear()
	game.selection.select_ids([healer.unit_id])
	hero.vitals.health = 5000
	var hp: float = hero.vitals.health
	var mp: float = healer.vitals.mana
	await key(KEY_K)
	check(game.selection.armed_skill_id==&"heal" and game.selection.preview_kind()==&"none","UX-06 ally targeting is direct unit picking, not circles")
	await capture("unit-target-aim")
	await click(screen(enemy))
	check(healer.vitals.mana==mp and game.selection.armed_skill_id==&"heal","UX-06 wrong team retains aim and does not spend MP")
	var feedback: int = hero.view.confirmations
	await click(screen(hero))
	check(hero.view.confirmations==feedback+1 and hero.view.confirmation_left>0,"UX-07 valid ally click confirms the exact unit")
	tick(healer)
	check(hero.vitals.health>hp and healer.vitals.mana<mp,"UX-06 manual heal uses same spell command")
	game.selection.select_ids([controller.unit_id])
	await key(KEY_B)
	check(game.selection.preview_kind()==&"none","UX-06 enemy unit spell has no radius or range ring")
	feedback = enemy.view.confirmations
	await click(screen(enemy))
	check(enemy.view.confirmations==feedback+1,"UX-07 enemy spell confirms clicked target")
	tick(controller)
	for effect: BattleSkillEffect in game.effects: effect.finish()
	game.effects.clear()
	game.selection.select_ids([guard.unit_id])
	feedback = enemy.view.confirmations
	await click(screen(enemy),MOUSE_BUTTON_RIGHT)
	check(guard.active.get("target")==enemy.unit_id and enemy.view.confirmations==feedback+1,"UX-07 right attack blinks the actual enemy")
	await capture("enemy-confirmation")
	check(is_equal_approx(hero.view.sprite.self_modulate.a,1.0) or hero.view.confirmation_left>0,"UX-07 feedback remains per-unit")
	enemy.view._update_confirmation(1)
	check(enemy.view.confirmation_left==0 and enemy.view.sprite.self_modulate.a==1,"UX-07 confirmation fades without changing alpha permanently")
	ready(guard)
	game.selection.select_ids([])
	feedback = enemy.view.confirmations
	await click(screen(enemy),MOUSE_BUTTON_RIGHT)
	check(enemy.view.confirmations==feedback,"UX-07 no selected army means no false confirmation")
	game.selection.select_ids([supplier.unit_id])
	check(not supplier.abilities.autocast_enabled(supply),"UX-08 mana supply begins manual")
	supplier.vitals.mana = 0
	game.hud._update_skill_availability()
	check(not game.hud.skill_buttons[&"supply"].disabled,"UX-08 zero MP still permits right-click auto switch")
	await click(game.hud.skill_buttons[&"supply"].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(supplier.abilities.autocast_enabled(supply) and supplier.active.is_empty() and game.selection.armed_skill_id==&"","UX-08 right-click enables auto without casting or issuing move")
	game.selection.select_ids([mage.unit_id])
	game.selection.select_ids([supplier.unit_id])
	check(supplier.abilities.autocast_enabled(supply),"UX-08 deselection preserves per-unit auto state")
	ready(supplier)
	mage.vitals.mana = 1
	supplier.think_left = 0
	before = supplier.casts
	tick(supplier,2)
	check(supplier.casts==before+1 and mage.vitals.mana>1,"UX-09 auto supply restores nearby ally MP")
	check(supplier.vitals.mana<10000,"UX-09 caster spends MP rather than restoring itself")
	await click(game.hud.skill_buttons[&"supply"].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	before = supplier.casts
	supplier.think_left = 0
	tick(supplier,2)
	check(not supplier.abilities.autocast_enabled(supply) and supplier.casts==before,"UX-08 right-click disables auto immediately")
	supplier.abilities.set_autocast(supply,true)
	for id: int in game.living_ids(0): game.get_unit(id).vitals.mana = 10000
	supplier.vitals.mana = 500
	supplier.think_left = 0
	before = supplier.casts
	tick(supplier,3)
	check(supplier.casts==before,"UX-09 full allies and self deficit do not waste auto MP")
	mage.vitals.mana = 1
	mage.position = supplier.position+Vector2(supply.range+100,0)
	supplier.think_left = 0
	tick(supplier,3)
	check(supplier.casts==before and supplier.position==Vector2(450,660),"UX-09 auto supply does not chase distant deficits")
	game.selection.select_ids([healer.unit_id])
	await click(game.hud.skill_buttons[&"heal"].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(healer.abilities.autocast_enabled(heal) and not supplier.abilities.autocast.has(heal.id),"UX-08 healing state does not leak to another unit")
	hero.position = healer.position+Vector2(40,0)
	hero.vitals.health = 9990
	ready(healer)
	healer.think_left = 0
	before = healer.casts
	tick(healer,2)
	check(healer.casts==before+1 and hero.vitals.health==10000,"UX-09 auto heal handles slight injury without old 62 percent gate")
	hero.vitals.health = 9900
	healer.abilities.auto_scan_left = 0
	healer.issue_command({"kind":"attack","target":enemy.unit_id})
	before = healer.casts
	tick(healer,2)
	check(healer.casts==before+1 and hero.vitals.health>9900,"UX-09 autocast still supports allies during an attack order")
	check(healer.active.get("kind")=="attack" and healer.active.get("target")==enemy.unit_id,"UX-09 interrupted attack resumes with same target")
	await capture("autocast")
	var clone: TacticalUnit = game.spawn_unit(healer.definition.duplicate(true) as UnitDefinition,0,Vector2(1100,1100),false)
	healer.abilities.set_autocast(heal,false)
	check(heal.automatic and clone.abilities.autocast_enabled(heal),"UX-08 toggling one caster never changes shared default or another owner")
	game.selection.select_ids([healer.unit_id,clone.unit_id])
	await click(game.hud.skill_buttons[&"heal"].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(healer.abilities.autocast_enabled(heal) and clone.abilities.autocast_enabled(heal),"UX-08 mixed multi-selection right-click enables all selected owners")
	await click(game.hud.skill_buttons[&"heal"].get_global_rect().get_center(),MOUSE_BUTTON_RIGHT)
	check(not healer.abilities.autocast_enabled(heal) and not clone.abilities.autocast_enabled(heal),"UX-08 second multi-owner click disables all selected owners")
	var cursor: BattleCursorGuard = game.cursor_guard
	cursor.set_process(false)
	cursor.focused = true
	await key(KEY_F1)
	check(cursor.enabled and cursor.confinement_active,"UX-02 F1 requests visible battle confinement")
	if DisplayServer.get_name()!="headless": check(Input.mouse_mode==Input.MOUSE_MODE_CONFINED,"UX-02 native backend receives confined-visible mode")
	await key(KEY_F1,true)
	check(cursor.enabled,"UX-02 F1 echo cannot toggle twice")
	cursor._focus_exited()
	check(not cursor.confinement_active,"UX-02 focus loss releases cursor")
	cursor._focus_entered()
	check(cursor.confinement_active,"UX-02 focus return restores requested lock")
	game.selection.cancel()
	await key(KEY_X)
	cursor.sync()
	check(not cursor.confinement_active and cursor.enabled,"UX-02 menus temporarily release requested lock")
	game.hud.close_windows()
	cursor.sync()
	check(cursor.confinement_active,"UX-02 closing menu restores confinement")
	await key(KEY_F1)
	check(not cursor.enabled and not cursor.confinement_active,"UX-02 second F1 releases lock")
	check(not GameSettings.rebind("command_attack",KEY_F1),"UX-02 F1 reserved against accidental skill binding")
	game.selection.sequence_entries = [{"unit":guard.unit_id,"skill":guard.available_skills()[0]}]
	game.selection.sequence_slots = [guard.unit_id]
	game.selection.sequence_index = 0
	before = guard.casts
	await key(KEY_E)
	tick(guard)
	check(guard.casts==before and game.selection.armed_skill_id==&"blast","UX-05 E only prepares the next caster")
	await click(Vector2(900,430))
	tick(guard)
	check(guard.casts==before+1,"UX-05 E still needs left-click confirmation")
	await key(KEY_F1)
	game.finish_battle("retreat")
	check(cursor.enabled and not cursor.confinement_active,"UX-02 results release actual cursor while retaining session preference")
	game.start_world()
	while game.mode!=&"world": await get_tree().process_frame
	cursor.sync()
	check(cursor.enabled and cursor.confinement_active,"UX-02 returning to world restores requested confinement")
	await key(KEY_F1)
	check(not cursor.enabled and not cursor.confinement_active,"UX-02 second world F1 releases lock")
	cursor.enabled = true
	game.mode = &"countdown"
	cursor.sync()
	check(cursor.confinement_active,"UX-02 countdown retains world confinement")
	game.mode = &"loading"
	cursor.sync()
	check(cursor.enabled and not cursor.confinement_active,"UX-02 loading temporarily releases without forgetting preference")
	cursor.release()
	check(not cursor.enabled and not cursor.confinement_active,"UX-02 explicit shutdown fully clears confinement")
	var report: Dictionary = {"engine":Engine.get_version_info()["string"],"passed":passed,"failed":failures.size(),"failures":failures,"rendered":DisplayServer.get_name()!="headless","tests":checks,"manual_pointer_boundary":"not exercised by physical hardware"}
	var file: FileAccess = FileAccess.open("res://artifacts/world/combat-ux-%s-results.json" % ("render" if report["rendered"] else "headless"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("COMBAT_UX_RESULT ",JSON.stringify({"passed":passed,"failed":failures.size(),"failures":failures,"rendered":report["rendered"]}))
	get_tree().quit(0 if failures.is_empty() else 1)

