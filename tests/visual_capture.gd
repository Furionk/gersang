extends Node
func _ready() -> void:
	call_deferred("_run")
func _run() -> void:
	var game: GameDirector = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	game.cinematic_camera = false
	while game.mode != &"world":
		await get_tree().process_frame
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(TestArtifacts.output("visual","world-preview.png"))
	game.start_battle(Catalog.encounters()[0])
	while game.mode != &"battle":
		await get_tree().process_frame
	game.camera.position = Iso.project(Vector2(740, 640))
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(TestArtifacts.output("visual","battle-preview.png"))
	var mage: TacticalUnit = game.get_unit(game.roster_ids[3])
	var guard: TacticalUnit = game.get_unit(game.roster_ids[1])
	var enemy: TacticalUnit = game.get_unit(game.living_ids(1)[0])
	enemy.position = mage.position + Vector2(70, 10)
	mage.issue_command({"kind": "cast", "skill": mage.definition.skills[0], "point": enemy.position})
	guard.issue_command({"kind": "cast", "skill": guard.definition.skills[0], "point": enemy.position})
	await get_tree().create_timer(0.62).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(TestArtifacts.output("visual","skills-preview.png"))
	game.hud.show_settings()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(TestArtifacts.output("visual","settings-preview.png"))
	game.hud.close_windows()
	for index: int in [1, 2]:
		game.start_battle(Catalog.encounters()[index])
		while game.mode != &"battle":
			await get_tree().process_frame
		await get_tree().create_timer(0.3).timeout
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(TestArtifacts.output("visual","terrain-%d-preview.png" % index))
	var gallery: Node = load("res://tests/animation_gallery.tscn").instantiate()
	add_child(gallery)
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(TestArtifacts.output("visual","animation-preview.png"))
	print("GERSANG_VISUAL_CAPTURE_OK")
	get_tree().quit()
