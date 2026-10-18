extends Node
func _ready() -> void: call_deferred("run")
func capture(path: String) -> void:
	for frame: int in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/world/"+path)
func run() -> void:
	var game: GameDirector = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	game.select_world_slot(6)
	var record: CharacterRecord = PartyProgress.selected()
	for item: StringName in [&"blade",&"coat",&"hat",&"charm"]: record.grant_and_equip(item)
	record.add_experience(CharacterRecord.CURVE.threshold(7))
	game.hud.progression.show_inventory()
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(800,450),Vector2i(900,900)]:
		get_window().size = extent
		await capture("character-inventory-%dx%d.png" % [extent.x,extent.y])
	get_window().size = Vector2i(1280,720)
	game.hud.progression.show_stats()
	await capture("character-stats-1280x720.png")
	game.select_world_slot(0)
	record = PartyProgress.selected()
	record.add_experience(CharacterRecord.CURVE.threshold(31))
	record.allocate("strength",100)
	game.hud.progression.preview_fields["magic_resistance"].value = 50
	await capture("character-formula-1280x720.png")
	print("CHARACTER_CAPTURE_PASS")
	get_tree().quit()
