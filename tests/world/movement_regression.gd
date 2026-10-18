extends Node
var passed: int = 0
var failed: int = 0
var game: GameDirector
var collecting: bool = false
var trace: Array[Vector2] = []
func check(condition: bool, caption: String) -> void:
	if condition: passed += 1; print("PASS | ",caption)
	else: failed += 1; push_error("FAIL | "+caption)
func _ready() -> void:
	get_tree().create_timer(35).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func run() -> void:
	var metrics: Dictionary = WorldMovementChecks.run(check,PartyProgress.serialize())
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode != &"world": await get_tree().process_frame
	game.set_physics_process(false)
	var position: Vector2 = game.world_hero.position
	game.world_pose.step(position-Vector2(2,2),position)
	var expected_pose: Vector2 = game.world_pose.sample(Engine.get_physics_interpolation_fraction())
	game.world_hero.view._process(1.0/120.0)
	check(game.world_hero.view.position.distance_to(Iso.project(expected_pose))<0.01,"MOVE-14 actual sprite renders interpolated world pose")
	var camera_before: Vector2 = game.camera.position
	game._process(1.0/120.0)
	var expected_camera: Vector2 = camera_before.lerp(Iso.project(expected_pose)+Vector2(130,0),MovementFeel.follow_alpha(1.0/120.0))
	check(game.camera.position.distance_to(expected_camera)<0.01,"MOVE-15 actual camera and sprite consume same pose and response")
	var speed_before: float = game.world_hero.combat_stats["speed"]
	game.world_hero.combat_stats["speed"] = speed_before*1.5
	game.world_hero.desired_velocity = Vector2.RIGHT*100
	game.world_hero.view._process(1.0/60.0)
	var world_animation: float = game.world_hero.view.sprite.speed_scale
	game.mode = &"battle"
	game.world_hero.view._process(1.0/60.0)
	check(is_equal_approx(world_animation,game.world_hero.view.sprite.speed_scale),"MOVE-16 world/battle animation cadence uses identical speed scaling")
	game.mode = &"world"
	game.world_hero.combat_stats["speed"] = speed_before
	var original_fps: int = Engine.max_fps
	var original_vsync: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.frame_post_draw.connect(collect_frame)
	var frame_metrics: Array[Dictionary] = []
	for fps: int in [30,120]:
		Engine.max_fps = fps
		var from: Vector2 = Vector2(4900,2400)
		var target: Vector2 = from+Vector2(600,600)
		game.world_context.player_path.clear()
		game.world_context.state["player"].merge({"position":from,"facing":Vector2(1,1).normalized()},true)
		game.world_hero.position = from
		game.world_pose.reset(from)
		game.camera.position = Iso.project(from)+Vector2(130,0)
		game.world_hero.desired_velocity = Vector2.ZERO
		game.world_hero.view._process(0)
		# Finish the previous trial's submitted frame before opening a new trace.
		if DisplayServer.get_name() != "headless": await RenderingServer.frame_post_draw
		game.world_context.move_player(target)
		var clock: int = game.world_context.state["world_time_ms"]
		trace.clear()
		collecting = true
		game.set_physics_process(true)
		await get_tree().create_timer(2.0).timeout
		game.set_physics_process(false)
		collecting = false
		var duration: float = float(game.world_context.state["world_time_ms"]-clock)/1000.0
		var travelled: float = from.distance_to(game.world_context.state["player"]["position"])
		var actual_speed: float = travelled/maxf(0.01,duration)
		var lateral: float = 0
		var backwards: int = 0
		for i: int in trace.size():
			lateral = maxf(lateral,absf(trace[i].x-Iso.project(from).x))
			if i>0 and trace[i].y<trace[i-1].y-0.05: backwards += 1
		check(absf(actual_speed-game.world_context.player_movement_speed())<0.15,"MOVE-17 live movement speed stable at " + str(fps) + " FPS")
		if DisplayServer.get_name() != "headless":
			check(trace.size()>10 and lateral<0.05 and backwards==0,"MOVE-18 rendered vertical trace has no sideways/reverse jitter at " + str(fps) + " FPS")
		frame_metrics.append({"fps_cap":fps,"speed":actual_speed,"frames":trace.size(),"lateral":lateral,"backwards":backwards})
	metrics["live_frames"] = frame_metrics
	RenderingServer.frame_post_draw.disconnect(collect_frame)
	Engine.max_fps = original_fps
	DisplayServer.window_set_vsync_mode(original_vsync)
	game.set_physics_process(false)
	var report_path: String = "res://artifacts/world/movement-results.json" if DisplayServer.get_name() == "headless" else "res://artifacts/world/movement-results-rendered.json"
	var file: FileAccess = FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failed,"metrics":metrics},"\t"))
	file.close()
	print("MOVEMENT_METRICS ",JSON.stringify(metrics))
	print("WORLD_MOVEMENT_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed == 0 else 1)

func collect_frame() -> void:
	if collecting and game != null and game.world_hero != null:
		trace.append(game.world_hero.view.position)
