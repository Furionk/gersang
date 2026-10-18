class_name BackgroundMusic
extends Node
## Presentation only: survives GameDirector._clear_level(), never touches saves.
const TRACKS: Dictionary = {
	"field": "res://art/music/巨商 online 【BGM】中國 (ChinaField) [rLTXbMCoJrs].mp3",
	"shaolin": "res://art/music/巨商 online 【BGM】少林寺 (shaolin temple) [zrPhKcU-LWQ].mp3",
	"battle": "res://art/music/巨商 online 【BGM】戰鬥音樂 (Battle music) [UOMmdIihqx0].mp3",
	"town": "res://art/music/巨商 online 【BGM】中國城鎮 (ChinaVillage) [DCfrh2-R3bs].mp3",
	"lake": "res://art/music/巨商 online 【BGM】妖魅湖 (Ghost lake) [CNHCjXSIAog].mp3",
	"well": "res://art/music/巨商 online 【BGM】武寧王陵 (weapon grave) [rlcPdqbAfhg].mp3"
}
@export_range(0.1, 5.0) var fade_seconds: float = 1.2
@export_range(-40.0, 0.0) var music_volume_db: float = -12.0
var current_track: String = ""
var players: Dictionary = {}
var transition: Tween

func _ready() -> void:
	if OS.has_feature("web_no_bgm"): return
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index("Music") < 0:
		AudioServer.add_bus()
		var index: int = AudioServer.bus_count - 1
		AudioServer.set_bus_name(index, "Music")
		AudioServer.set_bus_send(index, "Master")
	for key: String in TRACKS:
		if not ResourceLoader.exists(TRACKS[key]): continue
		var source: AudioStreamMP3 = load(TRACKS[key]) as AudioStreamMP3
		if source == null: continue
		var voice: AudioStreamPlayer = AudioStreamPlayer.new()
		voice.name = key
		voice.bus = &"Music"
		# Looping is local; do not modify imported/shared source resources.
		var stream: AudioStreamMP3 = source.duplicate() as AudioStreamMP3
		stream.loop = true
		voice.stream = stream
		voice.volume_linear = 0.0
		add_child(voice)
		players[key] = voice

static func track_for(mode: StringName, map_id: String) -> String:
	if mode in [&"battle", &"results"]: return "battle"
	match map_id:
		"shaolin_temple": return "shaolin"
		"qingling_town": return "town"
		"millennium_lake": return "lake"
		"well_1", "well_2": return "well"
	return "field"

func follow(mode: StringName, map_id: String) -> void:
	# Keep the last track through loading and countdown; switch only on arrival.
	if mode == &"loading": return
	play_track(track_for(mode, map_id))

func play_track(key: String) -> void:
	if key == current_track or not players.has(key): return
	if transition != null: transition.kill()
	current_track = key
	var incoming: AudioStreamPlayer = players[key]
	if not incoming.playing: incoming.play()
	transition = create_tween().set_parallel(true)
	for id: String in players:
		var voice: AudioStreamPlayer = players[id]
		transition.tween_property(voice, "volume_linear", db_to_linear(music_volume_db) if id == key else 0.0, fade_seconds)
	transition.finished.connect(_finish_transition)

func _finish_transition() -> void:
	for id: String in players:
		if id != current_track:
			(players[id] as AudioStreamPlayer).stop()

func _exit_tree() -> void:
	if transition != null: transition.kill()
	for voice: AudioStreamPlayer in players.values(): voice.stop()
