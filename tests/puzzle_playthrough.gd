extends Node
## Isolated physical-input acceptance fixture. No player save is read or written.
var game: GameDirector
var stage: String = "boot"
var observed: Dictionary = {}

func _ready() -> void:
	DisplayServer.window_set_title("巨箱 · 轉珠滑鼠驗收（隔離存檔）")
	call_deferred("run")

func run() -> void:
	game = load("res://main.tscn").instantiate()
	add_child(game)
	while game.mode!=&"world": await get_tree().process_frame
	get_window().title = "巨箱 · 轉珠滑鼠驗收（隔離存檔）"
	game.set_physics_process(false)
	var context: WorldContext = game.world_context
	for habitat: WorldHabitat in context.current_map().habitats:
		habitat.profile.rules.reinforcement_chance = 0.0
		habitat.profile.rules.reinforcement_join_chance = 0.0
		habitat.profile.rules.active = false
	var target: Dictionary = {}
	for party: Dictionary in context.state.maps.river_bay.parties.values():
		if party.habitat_id=="puzzle_fire": target=party; break
	# Make a single short reproducible encounter, not a production balancing claim.
	target.deployed_units.resize(1)
	target.deployed_units[0].current_hp=60.0
	context.state.player.position=target.position+Vector2(35,0)
	context.state.player.protected_until_ms=0; context.state.player.cooldown_until_ms=0
	context.player_path.clear()
	game.world_hero.position=context.state.player.position
	game.world_pose.reset(game.world_hero.position)
	game.camera.position=Iso.project(target.position)
	game._sync_world_views()
	game.message.emit("滑鼠驗收：點擊中央火轉珠怪，進戰後把第一行第2顆珠向下拖一格。")
	stage="world"
	observed={"fixture":"one enemy / 60 HP / authored single-swap board","isolated":not PartyProgress.persistence_enabled,"world_clicked":false,"drag_events":0,"victory":false}

func _physics_process(delta: float) -> void:
	if game==null or stage=="boot": return
	if stage=="world" and not game.world_context.player_path.is_empty():
		game._physics_process(delta)
	if stage=="world" and game.world_context.state.mode=="ENCOUNTER":
		stage="countdown"; observed.world_clicked=true
	if stage=="countdown":
		game._physics_process(delta)
		if game.mode==&"battle":
			# Call the actual attack entry so UI acceptance does not depend on RTS AI timing.
			var ally: TacticalUnit=game.get_unit(game.roster_ids[0])
			for unit: TacticalUnit in game.units.values():
				if unit.team==1 and unit.definition.puzzle_monster!=null:
					game.basic_attack(unit,ally,0)
					break
			stage="enter"
	elif stage=="enter" and game.puzzle_battle!=null and game.puzzle_battle.phase=="play":
		var control: PuzzleController=game.puzzle_battle.controller
		control.board.cells.assign([1,0,1,2,3,4, 0,1,2,3,4,0, 2,3,4,0,1,2, 3,4,0,1,2,3, 4,0,1,2,3,4])
		stage="puzzle"
	elif stage=="puzzle":
		if game.puzzle_battle!=null:
			observed.drag_events=game.puzzle_battle.view.input_events
			observed.combos=game.puzzle_battle.controller.combos
		if game.mode==&"battle": stage="return"
	elif stage=="return":
		game._physics_process(delta)
		if game.mode==&"results":
			observed.victory=game.last_result=="victory"
			stage="done"
			FileAccess.open("res://artifacts/puzzle-world/physical-input.json",FileAccess.WRITE).store_string(JSON.stringify(observed,"\t"))
			capture.call_deferred()

func capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/puzzle-world/physical-victory.png")
