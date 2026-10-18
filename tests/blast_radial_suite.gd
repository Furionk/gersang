extends Node
var passed: int = 0
var failures: Array[String] = []
var game: GameDirector
func check(ok: bool, caption: String) -> void:
	if ok: passed+=1; print("PASS | ",caption)
	else: failures.append(caption); push_error("FAIL | "+caption)
func _ready() -> void:
	get_tree().create_timer(25).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func key(pressed: bool, echo_value: bool = false) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = int(GameSettings.bindings["skill_blast"])
	event.keycode = event.physical_keycode
	event.pressed = pressed
	event.echo = echo_value
	get_viewport().push_input(event,false)
	await get_tree().process_frame
func click(button: Button) -> void:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.position = get_viewport().get_stretch_transform()*button.get_global_rect().get_center()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	get_viewport().push_input(event,false)
	await get_tree().process_frame
	event = event.duplicate() as InputEventMouseButton
	event.pressed = false
	get_viewport().push_input(event,false)
	await get_tree().process_frame
func clear_effects() -> void:
	for effect: BattleSkillEffect in game.effects: effect.finish()
	game.effects.clear()
func run() -> void:
	LegacyPartyFixture.install()
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode!=&"world": await get_tree().process_frame
	game.start_battle(Catalog.encounters()[0])
	while game.mode!=&"battle": await get_tree().process_frame
	game.set_physics_process(false)
	game.set_process(false)
	check(not PartyProgress.persistence_enabled,"NOVA-01 isolated progress")
	var guard: TacticalUnit = game.get_unit(game.roster_ids[1])
	guard.position = Vector2(640,560)
	guard.vitals.mana = 1000
	guard.think_left = 20
	guard.attack_timer = 20
	game.selection.select_ids([guard.unit_id])
	var blast: SkillDefinition = guard.available_skills()[0]
	check(blast.instant_self_activation and blast.cast_time==0 and blast.cooldown==0,"NOVA-02 authored immediate self input, zero windup and CD")
	var before: int = guard.casts
	await key(true)
	guard.tick(1.0/60)
	check(guard.casts==before+1 and game.selection.armed==&"" and game.effects.size()==1,"NOVA-02 real I press releases on next fixed tick without AI or attack delay")
	await key(true,true)
	guard.tick(1.0/60)
	check(guard.casts==before+1,"NOVA-03 held-key echo cannot autocast")
	await key(false)
	await key(true)
	guard.tick(1.0/60)
	await key(false)
	check(guard.casts==before+2,"NOVA-03 fresh I press casts again with no left click or hidden cooldown")
	clear_effects()
	await click(game.hud.skill_buttons[&"blast"])
	guard.tick(1.0/60)
	check(guard.casts==before+3 and game.selection.armed==&"","NOVA-04 native skill icon directly casts without ground order")
	clear_effects()
	guard.vitals.mana = 0
	guard.issue_command({"kind":"move","point":guard.position+Vector2(150,0)})
	check(not game.selection.activate_skill(&"blast") and guard.active.get("kind")=="move" and guard.vitals.mana==0,"NOVA-05 insufficient MP does not interrupt old command")
	guard.vitals.mana = 1000
	guard.issue_command({"kind":"stop"})
	game.selection.sequence_slots = [guard.unit_id]
	game.selection.sequence_entries = [{"unit":guard.unit_id,"skill":blast}]
	game.selection.sequence_index = 0
	before = guard.casts
	game.selection.sequence_cast(Vector2.ZERO)
	guard.tick(1.0/60)
	check(guard.casts==before and game.selection.armed_skill_id==&"blast","NOVA-06 E retains explicit preparation contract")
	game.selection.confirm_skill(Vector2.ZERO)
	guard.tick(1.0/60)
	check(guard.casts==before+1,"NOVA-06 E prepared blast confirms once")
	clear_effects()
	game.resolve_skill(guard,blast,guard.position,-1)
	var effect: BattleSkillEffect = game.effects[0]
	var visual: SkillVfx = effect.visuals[0]
	var center: Vector2 = effect.origin
	var position: Vector2 = visual.position
	var sites: Array[Vector2] = []
	var sum: Vector2 = Vector2.ZERO
	var extent: Vector2 = Vector2.ZERO
	for i: int in visual.radial_offsets.size():
		sites.append(visual.radial_sprites[i].position)
		sum+=visual.radial_offsets[i]
		var projected: Vector2 = Iso.project(visual.radial_offsets[i]).abs()
		extent = extent.max(projected)
		check(visual.radial_offsets[i].length()<=blast.effect_data.radius+0.001,"NOVA-07 site stays inside planar radius "+str(i))
	check(visual.radial_offsets.size()==29 and sum.is_zero_approx() and is_equal_approx(extent.x/extent.y,2),"NOVA-07 symmetric filled 2:1 isometric circle, not eight moving spokes")
	var ages: Array[float] = [0.0,0.2,0.4,0.6,0.8]
	var counts: Array[int] = [1,5,9,21,29]
	guard.position+=Vector2(200,150)
	for phase: int in ages.size():
		effect.age = ages[phase]
		visual.age = ages[phase]
		visual._process(0)
		var visible_sites: int = 0
		var fixed: bool = true
		for i: int in visual.radial_sprites.size():
			if visual.radial_sprites[i].visible: visible_sites+=1
			fixed = fixed and visual.radial_sprites[i].position==sites[i]
		check(visible_sites==counts[phase] and fixed and visual.position==position and effect.origin==center,"NOVA-08 stationary centered layer expansion at "+str(ages[phase]))
		if DisplayServer.get_name()!="headless":
			# Present the caster at its release center; the displaced-caster assertion
			# above independently proves that the effect never follows movement.
			guard.position = center
			await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://artifacts/world/blast-layer-%d.png" % phase)
			guard.position = center+Vector2(200,150)
	clear_effects()
	var report: Dictionary = {"passed":passed,"failed":failures.size(),"failures":failures,"rendered":DisplayServer.get_name()!="headless","sites":29,"visible_layers":counts}
	var file: FileAccess = FileAccess.open("res://artifacts/world/blast-radial-%s-results.json" % ("render" if report["rendered"] else "headless"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print("BLAST_RADIAL_RESULT ",JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
