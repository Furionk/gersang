extends Node
## Actual authored profiles and generated streams, with no synthetic audio fixture.
var passed: int = 0
var failed: int = 0
var heard: Array[Dictionary] = []
func check(ok: bool, caption: String) -> void:
	if ok: passed += 1; print("PASS | ",caption)
	else: failed += 1; push_error("FAIL | "+caption)
func _ready() -> void:
	LegacyPartyFixture.install() # This suite verifies the original seven complete banks.
	GameSettings.unit_voice_muted = false
	GameSettings.unit_voice_volume = 0.85
	var game: GameDirector = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	for frame: int in 5: await get_tree().physics_frame
	game.set_physics_process(false)
	var voices: UnitVoiceManager = game.voices
	voices.player_cooldown = 0.0
	voices.event_cooldown = 0.0
	voices.response_played.connect(func(id: StringName, event: StringName, path: String) -> void: heard.append({"unit":id,"event":event,"path":path}))
	check(heard.is_empty(), "native world startup does not speak")
	for slot: int in PartyProgress.records.size():
		var record: CharacterRecord = PartyProgress.records[slot]
		var seen: Dictionary = {}
		for variation: int in 3:
			voices.stop()
			var count: int = heard.size()
			game.hud.world_hud._select(slot)
			check(heard.size() == count + 1 and heard.back().unit == record.definition.id and heard.back().event == &"inspect", "native portrait/dossier plays INSPECT " + String(record.definition.id))
			if heard.size() > count: seen[heard.back().path] = true
			check(voices.player.playing and voices.player.stream is AudioStreamOggVorbis, "real OGG player active for world response")
		check(seen.size() == 3, "world INSPECT uses all three real variations " + String(record.definition.id))
	# Reproduce normal-player rapid clicking: keep normal cooldowns, don't stop the stream.
	voices.player_cooldown = 0.8
	voices.event_cooldown = 2.0
	for click: int in 10:
		var count: int = heard.size()
		game.hud.world_hud._select(0)
		check(heard.size() == count + 1 and heard.back().unit == &"merchant", "rapid world portrait click emits exactly one real response")
	for click: int in 10:
		var count: int = heard.size()
		game.hud.progression.roster_buttons[0].pressed.emit()
		check(heard.size() == count + 1 and heard.back().unit == &"merchant", "same dossier character button responds every time")
	var before_refresh: int = heard.size()
	game.select_world_slot(0)
	game.hud.progression.refresh(0)
	check(heard.size() == before_refresh, "internal slot sync and refresh remain silent")
	voices.player_cooldown = 0.0
	voices.event_cooldown = 0.0
	game.hud.progression.close()
	game.start_battle(Catalog.encounters()[0])
	for frame: int in 3: await get_tree().physics_frame
	check(not voices.player.playing, "battle entry clears real world response")
	var enemy: TacticalUnit = game.get_unit(game.living_ids(1)[0])
	for id: int in game.roster_ids:
		var unit: TacticalUnit = game.get_unit(id)
		if unit == null or not unit.alive(): continue
		for event: StringName in [&"select", &"move", &"attack"]:
			var seen: Dictionary = {}
			for variation: int in 3:
				voices.stop()
				game.selection.select_ids([id])
				var count: int = heard.size()
				if event == &"select": game.hud._roster_select(game.roster_ids.find(id))
				else: game.selection.dispatch(String(event), enemy.position if event == &"attack" else Vector2(620,550), enemy.unit_id if event == &"attack" else -1)
				check(heard.size() == count + 1 and heard.back().unit == unit.definition.id and heard.back().event == event, "native battle hook plays " + String(unit.definition.id) + "/" + String(event))
				if heard.size() > count: seen[heard.back().path] = true
				check(voices.player.playing and voices.player.stream is AudioStreamOggVorbis, "real OGG player active for battle response")
			check(seen.size() == 3, "battle event uses all three real variations " + String(unit.definition.id) + "/" + String(event))
	voices.reset_context()
	voices.acknowledge(game.roster_ids, &"select")
	check(heard.back().unit == game.get_unit(game.roster_ids[0]).definition.id, "real group bank selects one representative")
	voices.player_cooldown = 0.8
	voices.event_cooldown = 2.0
	for click: int in 10:
		var count: int = heard.size()
		game.hud._roster_select(0)
		check(heard.size() == count + 1 and heard.back().unit == &"merchant" and heard.back().event == &"select", "rapid battle portrait responds every time with real assets")
	check(voices.player.max_polyphony == 1, "rapid real clicks never overlap multiple response players")
	# Feed genuine viewport mouse events through normal selection input routing.
	game.hud.close_windows()
	await get_tree().create_timer(0.3).timeout
	var clicked_unit: TacticalUnit = game.get_unit(game.roster_ids[1])
	for click: int in 5:
		var count: int = heard.size()
		var at: Vector2 = game.get_canvas_transform() * (Iso.project(clicked_unit.position) + Vector2(0, -35))
		var motion: InputEventMouseMotion = InputEventMouseMotion.new()
		motion.position = at
		get_viewport().push_input(motion, true)
		await get_tree().process_frame
		for pressed: bool in [true, false]:
			var button: InputEventMouseButton = InputEventMouseButton.new()
			button.position = at
			button.button_index = MOUSE_BUTTON_LEFT
			button.pressed = pressed
			get_viewport().push_input(button, true)
			await get_tree().process_frame
		var responded: bool = heard.size() == count + 1 and heard.back().unit == clicked_unit.definition.id and heard.back().event == &"select"
		if not responded: print("CLICK_DIAGNOSTIC index=",click," count_delta=",heard.size()-count," selected=",game.selection.selected_ids," expected=",clicked_unit.unit_id," screen=",at)
		check(responded, "viewport repeated unit click emits exactly one real SELECT")
	var trial: Dictionary = game.debug_trial_unit("ninja")
	check(bool(trial.get("ok", false)), "existing F2 trial path spawns playable English ninja")
	var ninja: TacticalUnit = game.get_unit(int(trial.get("unit_id", -1)))
	if ninja != null:
		check(ninja.definition.voice_profile != null and ninja.definition.voice_profile.language == "en" and ninja.definition.voice_profile.gender == "male", "actual trial ninja uses English male profile")
		var selections: Dictionary = {}
		for click: int in 4:
			var count: int = heard.size()
			game.selection.select_ids([ninja.unit_id], false, true)
			check(heard.size() == count + 1 and heard.back().unit == &"ninja" and heard.back().event == &"select", "trial ninja repeated selection uses real English audio")
			if heard.size() > count: selections[heard.back().path] = true
		check(selections.size() == 2, "ninja clicks cycle exactly the two requested lines")
		voices.player_cooldown = 0.0
		voices.event_cooldown = 0.0
		for event: StringName in [&"move", &"attack"]:
			var seen: Dictionary = {}
			for index: int in ninja.definition.voice_profile.paths_for(event).size():
				voices.stop()
				var count: int = heard.size()
				game.selection.dispatch(String(event), enemy.position if event == &"attack" else Vector2(620,550), enemy.unit_id if event == &"attack" else -1)
				check(heard.size() == count + 1 and heard.back().unit == &"ninja" and heard.back().event == event, "ninja command plays native " + String(event))
				if heard.size() > count: seen[heard.back().path] = true
			check(seen.size() == ninja.definition.voice_profile.paths_for(event).size(), "ninja complete command variation bank " + String(event))
	game.queue_free()
	await get_tree().process_frame
	var report: FileAccess = FileAccess.open("res://artifacts/unit-voices/real-assets-results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed":passed,"failed":failed,"audible_human_listening":"unverified","uses_synthetic_streams":false}))
	print("UNIT_VOICE_REAL_ASSETS_RESULTS passed=",passed," failed=",failed)
	get_tree().quit(0 if failed == 0 else 1)
