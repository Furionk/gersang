extends "res://tests/rainbow_action_suite.gd"

func shot(title: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await super.shot(title)
	if title != "02-action-battle": return
	var window := get_window()
	var previous := window.size
	var previous_content := window.content_scale_size
	for dimensions: Vector2i in [Vector2i(800,450), Vector2i(1280,720), Vector2i(1600,900)]:
		window.size = dimensions
		window.content_scale_size = dimensions
		for frame: int in 8: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var hud: RainbowActionHud = game.action_battle.hud
		var bounds := Rect2(Vector2.ZERO, get_viewport().get_visible_rect().size)
		for kind: StringName in hud.action_buttons:
			check(bounds.encloses(hud.action_buttons[kind].get_global_rect()), "ability inside viewport: %s %s" % [kind,dimensions])
		check(not hud.roster_panel.get_global_rect().intersects(hud.actions.get_global_rect()), "portrait and ability docks do not overlap: %s" % dimensions)
		get_viewport().get_texture().get_image().save_png("res://artifacts/rainbow-gui-2026-10-16/hud-%dx%d.png" % [dimensions.x,dimensions.y])
	window.size = previous
	window.content_scale_size = previous_content
	for frame: int in 4: await get_tree().process_frame
