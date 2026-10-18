extends Node
var failed:=0
var passed:=0
func check(value:bool,label:String)->void:
	if value: passed+=1
	else: failed+=1; push_error("MONKEY_UI_FAIL "+label)
func _ready()->void:
	var g:MonkeyGarden=load("res://features/monkey/garden.tscn").instantiate(); add_child(g)
	await get_tree().physics_frame
	g.set_physics_process(false);g.intro=0;g.drag_camera=true
	check(not g.pause_panel.visible and not g.active,"entry has no confirmation window")
	var initial:=g.time_left
	g._physics_process(1.0)
	check(g.hud.countdown_text=="2" and not g.active and g.time_left==initial,"countdown freezes combat timer")
	g.pause_game();g._physics_process(1.0)
	check(g.entry_countdown==2.0 and g.pause_panel.visible,"focus loss pauses countdown")
	g.resume_game();g._physics_process(2.0)
	check(g.active and not g.pause_panel.visible and g.started,"countdown automatically starts gameplay")
	g.open_wheel();g.tick_clock(2)
	check(g.hud.wheel_open and not g.active and g.time_left==initial,"wheel freezes combat and timer")
	var key:=InputEventKey.new();key.pressed=true;key.physical_keycode=KEY_5;g._input(key)
	check(g.hud.preview==4 and g.gadget==1,"number key previews without equipping")
	g.close_wheel(false)
	check(g.active and g.gadget==1 and not g.using_tool,"cancel resumes without attacking")
	g.open_wheel();g.hud.preview=3;g.close_wheel(true)
	check(g.gadget==3 and g.active and not g.using_tool,"equip commits without attacking")
	g.gadget=1;g.begin_swing();g.open_wheel();g.hud.preview=0;g.close_wheel(true)
	check(g.gadget==1 and g.queued_gadget==0 and g.swing==0,"wheel cannot cancel committed net swing")
	g._tick_swing(.51);check(g.gadget==0,"queued tool equips after recovery")
	g.open_wheel();g.pause_game();check(not g.hud.wheel_open and not g.active,"focus loss closes wheel into pause")
	g.resume_game();g.hp=225;g.max_hp=230;g.update_hud()
	g.hud._process(0)
	check(g.hp==225 and g.max_hp==230,"grouped HUD preserves fractional hearts")
	check(g.hud.hud_hit(g.hud.origin+Vector2(900,65)*g.hud.factor)==1,"scaled HUD tool hit region")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/monkey-village/ui-hud-native.png")
		g.open_wheel();g.hud.preview=1
		await get_tree().process_frame;await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/monkey-village/ui-wheel-native.png")
	g.queue_free();await get_tree().process_frame
	print("MONKEY_UI_RESULT passed=%d failed=%d"%[passed,failed]);get_tree().quit(1 if failed else 0)
