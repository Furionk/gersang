extends "res://tests/rainbow_dungeon_suite.gd"
func run() -> void:
	context = WorldContext.new(); context.initialize(PartyProgress.serialize(),55047,true)
	context.save.enabled = false; WorldSession.context = context
	game = load("res://main.tscn").instantiate(); add_child(game)
	check(await wait_world(),"gallery world")
	game.set_physics_process(false)
	for portal: Dictionary in context.current_map().portals:
		if portal.id == "rainbow_door": context.state.player.position = portal.point
	check(context.begin_portal("rainbow_door").ok and await wait_world(),"gallery temple")
	for zone: int in [0,3,5,7,8]:
		var point := Vector2((24+zone%3*56)*32,(63+zone/3*52)*32)
		context.state.player.position = point + Vector2(100,150)
		game._physics_process(1.0/60.0)
		game.camera.position = Iso.project(point); game.camera.zoom = Vector2.ONE*0.7
		for frame: int in 4: await get_tree().process_frame
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://artifacts/rainbow-overhaul/zone-%d.png" % zone)
	finish()
