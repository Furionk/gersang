@tool
extends EditorPlugin
func _enter_tree() -> void:
	if DisplayServer.get_name()=="headless" or "--web-export-child" in OS.get_cmdline_user_args(): return
	call_deferred("run")
func run() -> void:
	await get_tree().create_timer(5.0).timeout
	EditorInterface.set_plugin_enabled("web_export",false)
	await get_tree().create_timer(1.0).timeout
	assert(not EditorInterface.is_plugin_enabled("web_export"))
	EditorInterface.set_plugin_enabled("web_export",true)
	await get_tree().create_timer(1.0).timeout
	var panel:Window=load("res://addons/web_export/panel.gd").new()
	EditorInterface.get_base_control().add_child(panel)
	panel.popup_centered(Vector2i(900,720))
	await get_tree().create_timer(0.5).timeout
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	panel.get_texture().get_image().save_png("res://../../editor-panel-final.png")
	panel.get_child(0).get_child(0).get_child(0).current_tab=1
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	panel.get_texture().get_image().save_png("res://../../editor-advanced-final.png")
	panel.start("build")
	await get_tree().create_timer(1.0).timeout
	RenderingServer.force_draw(false)
	await get_tree().process_frame
	panel.get_texture().get_image().save_png("res://../../editor-progress.png")
	panel.cancel()
	var began:int=Time.get_ticks_msec()
	while panel.process>0 and Time.get_ticks_msec()-began<30000:
		await get_tree().create_timer(0.2).timeout
	var result:Dictionary=load("res://addons/web_export/core/files.gd").json_read(panel.job.path_join("result.json"))
	print("PLUGIN_CANCEL_RESULT ",result)
	print("PLUGIN_LIFECYCLE_RESULT enabled=",EditorInterface.is_plugin_enabled("web_export"))
	panel.shutdown();panel.queue_free()
	EditorInterface.set_plugin_enabled("web_export",false)
	await get_tree().create_timer(1.0).timeout
	get_tree().quit(0 if str(result.get("error","")).contains("Cancelled") else 1)
