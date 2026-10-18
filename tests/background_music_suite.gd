extends Node
var failures: int = 0
var passed: int = 0
func check(ok: bool, caption: String) -> void:
	if ok: passed += 1; print("PASS | ",caption)
	else: failures += 1; push_error("FAIL | "+caption)
func _ready() -> void:
	var music: BackgroundMusic = BackgroundMusic.new()
	music.fade_seconds = 0.2
	add_child(music)
	for pair: Array in [["river_bay","field"],["shaolin_temple","shaolin"],["qingling_town","town"],["millennium_lake","lake"],["well_1","well"],["well_2","well"]]:
		check(BackgroundMusic.track_for(&"world",pair[0]) == pair[1],"map route "+pair[0])
	check(BackgroundMusic.track_for(&"battle","shaolin_temple")=="battle","battle overrides location")
	check(BackgroundMusic.track_for(&"results","river_bay")=="battle","results retains battle music")
	for id: String in music.players:
		var voice: AudioStreamPlayer = music.players[id]
		check(voice.stream.get_length()>1.0 and (voice.stream as AudioStreamMP3).loop and voice.bus==&"Music","valid looping MP3 on Music bus "+id)
	await check_playback(music)
	music.queue_free()
	await get_tree().process_frame
	var game: GameDirector = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	for frame: int in 10: await get_tree().physics_frame
	check(game.mode==&"world" and game.music.current_track==("field" if game.music.players.has("field") else ""),"real director starts world with optional BGM")
	var persistent_music: BackgroundMusic = game.music
	game.start_battle(Catalog.encounters()[0])
	for frame: int in 10: await get_tree().physics_frame
	check(game.mode==&"battle" and game.music==persistent_music and game.music.current_track==("battle" if game.music.players.has("battle") else ""),"real battle transition retains optional music player")
	game.finish_battle("retreat")
	check(game.music.current_track==("battle" if game.music.players.has("battle") else ""),"real result retains optional battle BGM")
	game.start_world()
	for frame: int in 10: await get_tree().physics_frame
	check(game.mode==&"world" and game.music==persistent_music and game.music.current_track==("field" if game.music.players.has("field") else ""),"real return preserves music node with optional region BGM")
	game.queue_free()
	await get_tree().process_frame
	print("BGM_RESULTS passed=",passed," failed=",failures)
	get_tree().quit(0 if failures==0 else 1)

func check_playback(music: BackgroundMusic) -> void:
	if music.players.is_empty():
		for mode: StringName in [&"world", &"loading", &"countdown", &"battle", &"results"]:
			for map_id: String in ["river_bay", "shaolin_temple", "qingling_town", "millennium_lake", "well_1", "well_2"]:
				music.follow(mode, map_id)
		check(music.current_track.is_empty() and music.transition == null, "missing music leaves all map and battle routes silent")
		check(music.get_child_count() == 0, "missing tracks allocate no audio players")
		await get_tree().process_frame
		return
	music.follow(&"world","river_bay")
	await get_tree().create_timer(0.3).timeout
	var field: AudioStreamPlayer = music.players.field
	check(field.playing and is_equal_approx(field.volume_linear,db_to_linear(-12.0)),"field fades in")
	var old_tween: Tween = music.transition
	music.follow(&"countdown","river_bay")
	music.follow(&"loading","shaolin_temple")
	check(music.transition==old_tween and music.current_track=="field","same track/countdown/loading do not restart")
	music.follow(&"battle","river_bay")
	await get_tree().create_timer(0.08).timeout
	var battle: AudioStreamPlayer = music.players.battle
	check(field.playing and battle.playing and field.volume_linear>0.0 and battle.volume_linear>0.0,"crossfade overlaps both voices")
	var before: float = field.volume_linear
	music.follow(&"world","river_bay")
	check(is_equal_approx(field.volume_linear,before),"interrupted fade keeps current gain without snapping")
	music.follow(&"world","shaolin_temple")
	await get_tree().create_timer(0.3).timeout
	check((music.players.shaolin as AudioStreamPlayer).playing and not field.playing and not battle.playing,"rapid third transition cleans obsolete voices")
	music.follow(&"world","well_1")
	await get_tree().create_timer(0.3).timeout
	old_tween = music.transition
	music.follow(&"world","well_2")
	check(music.transition==old_tween,"well floors share continuous track")
	music.play_track("missing")
	check(music.current_track=="well","unknown request leaves current track intact")
