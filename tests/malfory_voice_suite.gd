extends Node
var passed: int = 0
var failed: int = 0
var heard: Array[Dictionary] = []
func check(ok: bool, caption: String) -> void:
	if ok: passed += 1; print("PASS | ",caption)
	else: failed += 1; push_error("FAIL | "+caption)
func _ready() -> void:
	GameSettings.unit_voice_volume = 0.85
	GameSettings.unit_voice_muted = false
	var game: GameDirector = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	for frame: int in 5: await get_tree().physics_frame
	game.set_physics_process(false)
	var profile: UnitVoiceProfile = (load("res://features/units/data/mercenaries/malfory.tres") as UnitDefinition).voice_profile
	check(profile != null and profile.language == "en" and profile.gender == "female", "native Malfory English female voice resource")
	var recruited: Dictionary = WorldSession.change_mercenary_roster("recruit", "res://features/units/data/mercenaries/malfory.tres")
	check(not bool(recruited.get("ok", false)), "fixed roster rejects duplicate recruitment")
	var record: CharacterRecord = PartyProgress.records[9]
	var recruited_id: String = record.persistent_id
	var deposited: Dictionary = WorldSession.change_mercenary_roster("deposit", "", 9)
	var withdrawn: Dictionary = WorldSession.change_mercenary_roster("withdraw", recruited_id)
	check(bool(deposited.get("ok",false)) and bool(withdrawn.get("ok",false)), "normal reserve withdraw deploys Malfory without replacing original data")
	var slot: int = -1
	for i: int in PartyProgress.records.size():
		if PartyProgress.records[i].persistent_id == recruited_id: slot = i
	check(slot >= 0 and PartyProgress.records.size() == 10, "Malfory active with preserved ten-person capacity")
	var voices: UnitVoiceManager = game.voices
	voices.response_played.connect(func(id: StringName, event: StringName, path: String) -> void: heard.append({"unit":id,"event":event,"path":path}))
	var paths: Dictionary = {}
	for click: int in 6:
		var count: int = heard.size()
		game.hud.world_hud._select(slot)
		check(heard.size() == count+1 and heard.back().unit == &"malfory" and heard.back().event == &"inspect", "repeated dossier clicks play real Malfory voice")
		if heard.size() > count: paths[heard.back().path] = true
	check(paths.size() == 3, "all three Malfory dossier variations cycle")
	game.hud.progression.close()
	game.start_battle(Catalog.encounters()[0])
	for frame: int in 3: await get_tree().physics_frame
	var caster: TacticalUnit
	for id: int in game.roster_ids:
		var unit: TacticalUnit = game.get_unit(id)
		if unit.definition.id == &"malfory": caster = unit
	check(caster != null, "normally recruited Malfory appears in real battle")
	voices.player_cooldown = 0.0
	voices.event_cooldown = 0.0
	var enemy: TacticalUnit = game.get_unit(game.living_ids(1)[0])
	if caster != null:
		for event: StringName in [&"select", &"move", &"attack"]:
			paths.clear()
			for index: int in 3:
				voices.stop()
				game.selection.select_ids([caster.unit_id])
				var count: int = heard.size()
				if event == &"select": game.selection.select_ids([caster.unit_id], false, true)
				else: game.selection.dispatch(String(event), enemy.position if event == &"attack" else Vector2(620,550), enemy.unit_id if event == &"attack" else -1)
				check(heard.size() == count+1 and heard.back().unit == &"malfory" and heard.back().event == event, "real Malfory battle " + String(event))
				if heard.size() > count: paths[heard.back().path] = true
				check(voices.player.playing and voices.player.stream is AudioStreamOggVorbis, "Malfory native OGG active on player")
			check(paths.size() == 3, "Malfory complete three-variation " + String(event))
	game.queue_free()
	await get_tree().process_frame
	var output: FileAccess = FileAccess.open("res://artifacts/unit-voices/malfory-voice-results.json",FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":passed,"failed":failed,"human_listening":"unverified"}))
	print("MALFORY_VOICE_RESULTS passed=",passed," failed=",failed)
	get_tree().quit(0 if failed == 0 else 1)
