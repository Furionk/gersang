class_name UnitVoiceManager
extends Node
signal response_played(unit_id: StringName, event: StringName, path: String)
@export var player_cooldown: float = 0.8
@export var event_cooldown: float = 2.0
@export var enemy_cooldown: float = 2.5
var director: GameDirector
var player: AudioStreamPlayer
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
var bags: Dictionary = {}
var previous: Dictionary = {}
var streams: Dictionary = {}
var event_times: Dictionary = {}
var enemy_seen: Dictionary = {}
var player_time: float = -INF
var enemy_time: float = -INF
var current_priority: int = -1

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	rng.randomize() # Never consume gameplay RNG.
	if AudioServer.get_bus_index(&"UnitVoice") < 0:
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, &"UnitVoice")
		AudioServer.set_bus_send(index, &"Master")
	player = AudioStreamPlayer.new()
	if OS.has_feature("web"): player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
	player.name = "UnitResponse"
	player.bus = &"UnitVoice"
	player.max_polyphony = 1
	add_child(player)
	player.finished.connect(func() -> void: current_priority = -1)
	GameSettings.changed.connect(apply_settings)
	apply_settings()

func apply_settings() -> void:
	var index: int = AudioServer.get_bus_index(&"UnitVoice")
	AudioServer.set_bus_volume_db(index, linear_to_db(maxf(0.0001, GameSettings.unit_voice_volume)))
	AudioServer.set_bus_mute(index, GameSettings.unit_voice_muted or GameSettings.unit_voice_volume <= 0.0)
	if GameSettings.unit_voice_muted or GameSettings.unit_voice_volume <= 0.0: stop()

func _process(_delta: float) -> void:
	if get_tree().paused:
		stop()
	elif director != null:
		if director.mode not in [&"world", &"battle", &"puzzle"] or (director.mode == &"battle" and director.hud != null and director.hud.is_modal_open()): stop()

func stop() -> void:
	if player != null: player.stop()
	current_priority = -1

func reset_context() -> void:
	stop()
	bags.clear()
	previous.clear()
	event_times.clear()
	enemy_seen.clear()
	player_time = -INF
	enemy_time = -INF

func _available(profile: UnitVoiceProfile, event: StringName) -> Array[String]:
	var paths: Array[String] = []
	if profile == null: return paths
	for path: String in profile.paths_for(event):
		if not streams.has(path) and ResourceLoader.exists(path):
			var stream: AudioStream = load(path) as AudioStream
			if stream != null: streams[path] = stream
		if streams.has(path): paths.append(path)
	return paths

func _next_path(key: String, paths: Array[String]) -> String:
	var bag: Array = bags.get(key, [])
	if bag.is_empty():
		bag = paths.duplicate()
		for i: int in range(bag.size() - 1, 0, -1):
			var j: int = rng.randi_range(0, i)
			var swap: String = bag[i]
			bag[i] = bag[j]
			bag[j] = swap
		if bag.size() > 1 and bag.back() == previous.get(key, ""):
			var swap: String = bag[0]
			bag[0] = bag.back()
			bag[bag.size() - 1] = swap
	var result: String = bag.pop_back()
	bags[key] = bag
	previous[key] = result
	return result

func request(profile: UnitVoiceProfile, event: StringName, instance_key: String, enemy: bool = false, now: float = -1.0, player_click: bool = false) -> bool:
	if profile == null or player == null or get_tree().paused or GameSettings.unit_voice_muted or GameSettings.unit_voice_volume <= 0.0: return false
	if director != null and (director.mode not in [&"world", &"battle"] or (director.mode == &"battle" and director.hud.is_modal_open())): return false
	if now < 0.0: now = Time.get_ticks_msec() / 1000.0
	var priority: int = 0 if enemy else 3 if event == &"attack" else 2 if event == &"move" else 1
	# Explicit selection/inspection always responds; a single channel restarts instead of stacking.
	var click_response: bool = player_click and not enemy and event in [&"select", &"inspect"]
	var interrupt: bool = player.playing and (click_response or priority > current_priority)
	if player.playing and not interrupt: return false
	var key: String = instance_key + ":" + String(event)
	if not click_response and now - float(event_times.get(key, -INF)) < event_cooldown: return false
	if enemy and now - enemy_time < enemy_cooldown: return false
	# Command priority bypasses global spacing; explicit clicks bypass both cooldowns.
	if not click_response and not enemy and not interrupt and now - player_time < player_cooldown: return false
	var paths: Array[String] = _available(profile, event)
	if paths.is_empty(): return false
	var path: String = _next_path(String(profile.unit_id) + ":" + String(event), paths)
	player.stop()
	player.stream = streams[path]
	current_priority = priority
	player.play()
	event_times[key] = now
	if enemy: enemy_time = now
	else: player_time = now
	response_played.emit(profile.unit_id, event, path)
	return true

func acknowledge(ids: Array[int], event: StringName) -> bool:
	if director == null or director.mode != &"battle": return false
	var candidates: Array[TacticalUnit] = []
	for id: int in ids:
		var unit: TacticalUnit = director.get_unit(id)
		if unit != null and unit.team == 0 and unit.alive() and not _available(unit.definition.voice_profile, event).is_empty(): candidates.append(unit)
	candidates.sort_custom(func(a: TacticalUnit, b: TacticalUnit) -> bool:
		var a_slot: int = director.roster_ids.find(a.unit_id)
		var b_slot: int = director.roster_ids.find(b.unit_id)
		if a_slot < 0: a_slot = 2147483647
		if b_slot < 0: b_slot = 2147483647
		if a_slot != b_slot: return a_slot < b_slot
		if a.definition.id != b.definition.id: return String(a.definition.id) < String(b.definition.id)
		return a.unit_id < b.unit_id)
	if candidates.is_empty(): return false
	var speaker: TacticalUnit = candidates[0]
	return request(speaker.definition.voice_profile, event, str(speaker.unit_id), false, -1.0, event == &"select")

func inspect_selected() -> bool:
	if director == null or director.mode != &"world": return false
	var record: CharacterRecord = PartyProgress.selected()
	return request(record.definition.voice_profile, &"inspect", record.persistent_id, false, -1.0, true)

func enemy_event(unit: TacticalUnit, event: StringName) -> bool:
	if director == null or director.mode != &"battle" or unit == null or unit.team != 1: return false
	var key: String = str(unit.unit_id) + ":" + String(event)
	if enemy_seen.has(key): return false
	enemy_seen[key] = true # One opportunity per life, even when throttled or missing assets.
	return request(unit.definition.voice_profile, event, str(unit.unit_id), true)

# Scripted puzzle turns are sequential attacks, not throttled RTS commands.
func puzzle_attack(profile: UnitVoiceProfile) -> float:
	if profile == null or player == null or get_tree().paused or GameSettings.unit_voice_muted or GameSettings.unit_voice_volume <= 0.0: return 0.0
	if director != null and director.mode != &"puzzle": return 0.0
	var paths: Array[String] = _available(profile, &"attack")
	if paths.is_empty(): return 0.0
	var path: String = _next_path(String(profile.unit_id)+":attack", paths)
	player.stop()
	player.stream = streams[path]
	player.stream_paused = false
	current_priority = 3
	player.play()
	response_played.emit(profile.unit_id, &"attack", path)
	return player.stream.get_length()
