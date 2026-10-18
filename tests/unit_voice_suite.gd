extends Node
var passed: int = 0
var failures: int = 0
var heard: Array[Dictionary] = []

func check(ok: bool, caption: String) -> void:
	if ok: passed += 1; print("PASS | ", caption)
	else: failures += 1; push_error("FAIL | " + caption)

func fixture(manager: UnitVoiceManager, id: StringName) -> UnitVoiceProfile:
	var profile: UnitVoiceProfile = UnitVoiceProfile.new()
	profile.unit_id = id
	for event: String in ["select", "move", "attack", "inspect", "engage", "death"]:
		var paths: Array[String] = []
		for index: int in 3:
			var path: String = "fixture://%s/%s/%d" % [id, event, index]
			var stream: AudioStreamWAV = AudioStreamWAV.new()
			stream.mix_rate = 22050
			stream.format = AudioStreamWAV.FORMAT_16_BITS
			var data: PackedByteArray = PackedByteArray()
			data.resize(22050 * 2 * 5)
			stream.data = data
			manager.streams[path] = stream
			paths.append(path)
		profile.events[event] = paths
	return profile

func listen(id: StringName, event: StringName, path: String) -> void:
	heard.append({"unit": id, "event": event, "path": path})

func _ready() -> void:
	GameSettings.settings_path = "user://unit_voice_test.cfg"
	GameSettings.unit_voice_volume = 0.85
	GameSettings.unit_voice_muted = false
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://features/audio/data/unit_voices.json"))
	var slots: int = 0
	var pilots: int = 0
	check(manifest.units.size() == 34, "34 authored voice identities including Malfory")
	for entry: Dictionary in manifest.units:
		var definition: UnitDefinition = load("res://" + entry.definition_path)
		check(definition.voice_profile != null and definition.voice_profile.unit_id == definition.id, "native resource assignment " + entry.unit_id)
		check(definition.voice_profile.voice_id == entry.voice.voice_id and definition.voice_profile.language == entry.language, "native voice metadata matches production manifest " + entry.unit_id)
		if entry.unit_id in ["mage", "supplier"]:
			check(definition.voice_profile.gender == "female" and definition.voice_profile.language == "ja", "corrected Japanese female identity " + entry.unit_id)
		if entry.unit_id == "ninja":
			check(definition.voice_profile.gender == "male" and definition.voice_profile.language == "en", "English male ninja identity")
			check(entry.events.select[0].text == "I smell magic in the air." and entry.events.select[1].text == "Be quick; time is mana." and entry.events.move[0].text == "Watch and learn" and entry.events.move[1].text == "Very clever", "ninja preserves all four exact requested phrases")
		if entry.unit_id == "malfory":
			check(definition.voice_profile.gender == "female" and definition.voice_profile.language == "en", "Malfory adult English female identity")
		for event: String in entry.events:
			var expected_paths: PackedStringArray = PackedStringArray()
			for line: Dictionary in entry.events[event]: expected_paths.append(line.path)
			var expected_count: int = int(entry.get("variation_counts", {}).get(event, 3))
			check(definition.voice_profile.paths_for(event) == expected_paths and expected_paths.size() == expected_count, "exact authored resource variations " + entry.unit_id + "/" + event)
			for line: Dictionary in entry.events[event]:
				slots += 1
				if line.pilot: pilots += 1
	check(slots == 258 and pilots == 11, "258 slots / unchanged 11 pilot clips")
	check(manifest.has("full_generation_approved") and typeof(manifest.full_generation_approved) == TYPE_BOOL, "explicit full generation review state")
	for entry: Dictionary in manifest.units:
		for event: String in entry.events:
			for line: Dictionary in entry.events[event]:
				if line.pilot or manifest.full_generation_approved:
					var stream: AudioStream = load(line.path) as AudioStream
					check(stream != null and stream.get_length() > 0.35 and stream.get_length() < 8.0, "real generated OGG imports " + entry.unit_id + "/" + line.id)
	var manager: UnitVoiceManager = UnitVoiceManager.new()
	add_child(manager)
	manager.response_played.connect(listen)
	var profile: UnitVoiceProfile = fixture(manager, &"fixture")
	var last: String = ""
	for cycle: int in 4:
		var seen: Dictionary = {}
		for index: int in 3:
			manager.stop()
			check(manager.request(profile, &"select", "one", false, 10.0 + (cycle * 3 + index) * 3), "shuffle play")
			var path: String = heard.back().path
			check(path != last, "no adjacent repeats across bag boundaries")
			seen[path] = true
			last = path
		check(seen.size() == 3, "each bag covers all three variations")
	manager.reset_context()
	check(manager.request(profile, &"select", "one", false, 100), "select starts")
	var random_state: int = manager.rng.state
	check(not manager.request(profile, &"select", "one", false, 100.1) and manager.rng.state == random_state, "non-click request throttled without consuming shuffle RNG")
	check(manager.request(profile, &"move", "one", false, 100.1), "MOVE interrupts SELECT despite global spacing")
	check(manager.request(profile, &"attack", "one", false, 100.2), "ATTACK interrupts MOVE")
	check(not manager.request(profile, &"move", "two", false, 104), "lower priority cannot interrupt attack")
	check(not manager.request(profile, &"attack", "two", false, 104), "equal priority dropped, no deferred queue")
	manager.stop()
	check(not manager.request(profile, &"attack", "one", false, 101), "same-event cooldown survives interruption")
	check(manager.request(profile, &"attack", "one", false, 103), "same-event cooldown expires")
	manager.reset_context()
	check(manager.request(profile, &"attack", "one", false, 800), "attack active before explicit click")
	for click: int in 10:
		check(manager.request(profile, &"select", "one", false, 800.01 + click * 0.01, true), "every explicit rapid click restarts SELECT even during ATTACK")
	check(manager.player.max_polyphony == 1 and manager.current_priority == 1, "click restart retains one voice channel")
	check(manager.request(profile, &"inspect", "one", false, 800.12, true), "explicit INSPECT also bypasses click cooldown")
	manager.reset_context()
	check(manager.request(profile, &"engage", "enemy1", true, 200), "enemy responds")
	check(manager.request(profile, &"select", "one", false, 200.1), "player preempts enemy")
	manager.stop()
	check(not manager.request(profile, &"death", "enemy2", true, 201), "enemy shared 2.5s throttle")
	check(manager.request(profile, &"death", "enemy2", true, 203), "enemy throttle expires")
	manager.reset_context()
	var missing: UnitVoiceProfile = UnitVoiceProfile.new()
	missing.unit_id = &"missing"
	missing.events = {"move": ["res://art/voices/nonexistent/move_01.ogg"]}
	check(not manager.request(missing, &"move", "missing", false, 300), "missing audio safely skips")
	check(manager.request(profile, &"move", "one", false, 300), "missing asset did not consume global cooldown")
	GameSettings.set_unit_voice(0.4, true)
	check(not manager.player.playing and not manager.request(profile, &"attack", "one", false, 304), "mute stops active playback and new requests")
	GameSettings.load_settings()
	check(GameSettings.unit_voice_muted and is_equal_approx(GameSettings.unit_voice_volume, 0.4), "voice settings survive save/load")
	GameSettings.set_unit_voice(0.85, false)
	manager.reset_context()
	manager.request(profile, &"move", "one", false, 400)
	get_tree().paused = true
	await get_tree().process_frame
	await get_tree().process_frame
	check(not manager.player.playing and not manager.request(profile, &"attack", "one", false, 404), "pause stops voice even with manager always processing")
	get_tree().paused = false
	manager.queue_free()
	await get_tree().process_frame
	await integration()
	print("UNIT_VOICE_RESULTS passed=", passed, " failed=", failures)
	var report: FileAccess = FileAccess.open("res://artifacts/unit-voices/runtime-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"passed": passed, "failed": failures, "manual_gui_listening": "unverified"}))
	get_tree().quit(0 if failures == 0 else 1)

func integration() -> void:
	var game: GameDirector = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	for frame: int in 5: await get_tree().physics_frame
	game.set_physics_process(false)
	var voice: UnitVoiceManager = game.voices
	voice.response_played.connect(listen)
	for record: CharacterRecord in PartyProgress.records:
		record.definition = record.definition.duplicate() as UnitDefinition
		record.definition.voice_profile = fixture(voice, record.definition.id)
	voice.reset_context()
	heard.clear()
	game.hud.progression.show_inventory()
	check(heard.size() == 1 and heard.back().event == &"inspect", "real world inventory opens one INSPECT response")
	voice.reset_context()
	heard.clear()
	game.hud.progression.refresh(0)
	game.hud.progression.update_vitals()
	check(heard.is_empty(), "refresh/stat values do not speak")
	game.select_world_slot(1, true)
	check(heard.size() == 1 and heard.back().unit == &"guard", "dossier character switch speaks the displayed identity")
	game.hud.progression.close()
	voice.reset_context()
	heard.clear()
	game.select_world_slot(0)
	check(heard.is_empty(), "closed dossier slot switch is silent")
	game.hud.progression.show_stats()
	check(heard.size() == 1 and heard.back().event == &"inspect", "real stats page opens INSPECT")
	game.hud.progression.close()
	game.start_battle(Catalog.encounters()[0])
	for frame: int in 5: await get_tree().physics_frame
	check(heard.size() == 1 and not voice.player.playing, "battle entry selection is silent and cancels old voice")
	for id: int in game.living_ids(0):
		var unit: TacticalUnit = game.get_unit(id)
		unit.definition = unit.definition.duplicate() as UnitDefinition
		unit.definition.voice_profile = fixture(voice, unit.definition.id)
	voice.reset_context()
	heard.clear()
	var ids: Array[int] = game.living_ids(0)
	var reverse_ids: Array[int] = ids.duplicate()
	reverse_ids.reverse()
	game.selection.select_ids(reverse_ids, false, true)
	check(heard.size() == 1 and heard.back().unit == game.get_unit(game.roster_ids[0]).definition.id, "group selects one deterministic roster speaker independent of input order")
	game.selection.dispatch("move", Vector2(600, 550))
	check(heard.size() == 2 and heard.back().event == &"move", "real MOVE command preempts selection")
	check(game.get_unit(ids[0]).active.get("kind") == "move", "voice does not delay gameplay command")
	var enemy_id: int = game.living_ids(1)[0]
	game.selection.dispatch("attack", game.get_unit(enemy_id).position, enemy_id)
	check(heard.size() == 3 and heard.back().event == &"attack", "real ATTACK preempts MOVE")
	voice.reset_context()
	heard.clear()
	game.selection.dispatch("attack_move", Vector2(620, 550), -1, true)
	check(heard.size() == 1 and heard.back().event == &"attack", "queued attack-move acknowledges attack once at issue")
	game.selection.tick()
	game.selection._sync_selection()
	game.selection.select_ids(ids)
	check(heard.size() == 1, "internal tick/sync/programmatic selection cannot produce response")
	voice.reset_context()
	heard.clear()
	game.hud._roster_select(1)
	check(heard.size() == 1 and heard.back().unit == &"guard", "battle HUD roster click uses player selection")
	voice.reset_context()
	heard.clear()
	game.selection.groups[1] = ids.duplicate()
	game.selection.recall_group(1)
	check(heard.size() == 1, "group recall acknowledges only once")
	voice.reset_context()
	heard.clear()
	var enemy: TacticalUnit = game.get_unit(enemy_id)
	enemy.definition = enemy.definition.duplicate() as UnitDefinition
	enemy.definition.voice_profile = fixture(voice, enemy.definition.id)
	var ally: TacticalUnit = game.get_unit(ids[0])
	enemy.position = ally.position + Vector2(enemy.definition.attack_range * 0.5, 0)
	enemy._engage(ally, 0.01)
	check(heard.size() == 1 and heard.back().event == &"engage", "real enemy at attack range speaks first engagement")
	voice.stop()
	voice.enemy_time = -INF
	enemy._engage(ally, 0.01)
	check(heard.size() == 1, "repeated enemy engage cannot repeat voice")
	enemy.vitals.health = 0
	enemy._die()
	check(heard.size() == 2 and heard.back().event == &"death", "real death speaks after HP reaches zero")
	voice.stop()
	voice.enemy_time = -INF
	game._unit_died(enemy_id)
	check(heard.size() == 2, "duplicate death notification cannot repeat")
	voice.reset_context()
	heard.clear()
	var dead_ids: Array[int] = [enemy_id]
	check(not voice.acknowledge(dead_ids, &"select"), "dead/enemy cannot represent a player group")
	var rng_state: int = game.rng.state
	voice.acknowledge(ids, &"move")
	check(game.rng.state == rng_state, "voice shuffle leaves gameplay RNG exact")
	game.hud.show_settings()
	await get_tree().process_frame
	await get_tree().process_frame
	check(not voice.player.playing, "battle modal pause stops playback")
	game.hud.close_windows()
	voice.reset_context()
	voice.acknowledge(ids, &"move")
	game.finish_battle("retreat")
	check(not voice.player.playing, "battle results stop response")
	game.start_world()
	check(voice.enemy_seen.is_empty() and voice.event_times.is_empty(), "world transition clears cooldown and instance context")
	game.queue_free()
	await get_tree().process_frame
