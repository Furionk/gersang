extends Node
var game: GameDirector
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	PartyProgress.records[0].add_experience(140)
	PartyProgress.records[0].allocate("strength")
	PartyProgress.records[0].allocate("strength")
	PartyProgress.records[0].allocate("luck")
	PartyProgress.records[0].use_item(0)
	PartyProgress.records[0].use_item(1)
	PartyProgress.records[0].health = 190
	PartyProgress.records[0].mana = 55
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode != &"world":
		await get_tree().process_frame
	game.set_physics_process(false)
	game.hud.progression.toggle_stats()
	game.hud.progression.toggle_inventory()
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(1024,768),Vector2i(1720,720),Vector2i(800,450)]:
		get_window().size = extent
		for frame: int in 10:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image: Image = get_viewport().get_texture().get_image()
		image.save_png(TestArtifacts.output("progression","progression-%dx%d.png" % [extent.x,extent.y]))
		var visible: Rect2 = get_viewport().get_visible_rect()
		var stat: Panel = game.hud.progression.stat_panel
		var inventory: Panel = game.hud.progression.inventory_panel
		if not visible.encloses(stat.get_global_rect()) or not visible.encloses(inventory.get_global_rect()) or stat.get_global_rect().intersects(inventory.get_global_rect()):
			push_error("Panels outside viewport or overlapping at %s" % extent)
			get_tree().quit(1)
			return
	print("GERSANG_PROGRESSION_VISUAL_PASS | five resized windows")
	get_tree().quit(0)
