extends Node
func _ready() -> void:
	call_deferred("run")
func run() -> void:
	var game: GameDirector = load("res://main.tscn").instantiate() as GameDirector
	add_child(game); game.audio.muted = true
	while game.mode != &"world": await get_tree().process_frame
	game.set_physics_process(false)
	game.select_world_slot(1)
	game.hud.toggle_item_debug()
	var panel: ItemDebugPanel = game.hud.item_debug
	panel.category.select(4); panel.rebuild_list()
	for i: int in panel.displayed.size():
		if panel.displayed[i].id == &"gs_long_spear": panel.list.select(i); panel._select_item(i); break
	panel.perform("equip")
	for extent: Vector2i in [Vector2i(1280,720),Vector2i(800,450)]:
		get_window().size = extent
		for i: int in 12: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/world/items-debug-%dx%d.png" % [extent.x,extent.y])
	get_window().size = Vector2i(1280,720)
	panel.category.select(0); panel.rebuild_list()
	for i: int in 12: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/world/items-debug-consumables.png")
	print("ITEMS_CAPTURE_PASS")
	get_tree().quit()
