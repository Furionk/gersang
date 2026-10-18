extends Node
func _ready() -> void: call_deferred("run")
func run() -> void:
	var game: GameDirector = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	game.set_process(false)
	game.world_hover.set_process(false)
	var samples: Array[Dictionary] = []
	for pair: Array in [["gate",Vector2(4284.5,2723.5)],["woodlands",Vector2(3100,1300)],["bridge",Vector2(1250,2050)]]:
		game.camera.position = Iso.project(pair[1])
		for frame: int in 10: await get_tree().process_frame
		var times: Array[float] = []
		var draws: Array[float] = []
		var previous: int = Time.get_ticks_usec()
		for frame: int in 120:
			await get_tree().process_frame
			var now: int = Time.get_ticks_usec()
			times.append((now-previous)/1000.0)
			previous = now
			draws.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		times.sort()
		draws.sort()
		samples.append({"view":pair[0],"frame_ms_p50":times[60],"frame_ms_p95":times[114],"draw_calls_p50":draws[60],"samples":120})
	var report: Dictionary = {"engine":Engine.get_version_info().string,"gpu":RenderingServer.get_video_adapter_name(),"display":DisplayServer.get_name(),"fps_cap":Engine.max_fps,"scope":"isolated rendered world; stationary camera, AI and hover disabled; not a combat or low-end hardware guarantee","views":samples}
	var file: FileAccess = FileAccess.open("res://artifacts/river-enrichment-2026-10-10/benchmark.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("RIVER_BENCHMARK ",JSON.stringify(report))
	get_tree().quit()
