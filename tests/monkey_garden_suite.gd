extends Node
var failed: int=0
var passed: int=0
func check(value: bool, label_: String) -> void:
	if value: passed+=1
	else: failed+=1; push_error("MONKEY_FAIL "+label_)
func _ready() -> void:
	var garden: MonkeyGarden=load("res://features/monkey/garden.tscn").instantiate()
	add_child(garden)
	await get_tree().physics_frame
	check(garden.monkeys.size()==5,"five monkeys")
	check(garden.tools.size()==5,"five tools")
	check(garden.monkeys[0].animator!=null,"monkey animations")
	print("MONKEY_ANIMATIONS ",garden.monkeys[0].animator.get_animation_list())
	print("CATCHER_ANIMATIONS ",garden.animation.get_animation_list() if garden.animation else [])
	check(garden.get_node("GardenNavigation").navigation_mesh.get_polygon_count()>0 and garden.stable_ground(Vector3.ZERO) and not garden.stable_ground(Vector3(0,0,-9.8)),"baked navigation and stable recovery support")
	garden.hp=37; garden.hurt(10,garden.player.position)
	check(is_equal_approx(garden.hp,27),"HP damage preserves fractional hearts")
	garden.hurt(10,garden.player.position)
	check(is_equal_approx(garden.hp,27),"invulnerability prevents duplicate hit")
	garden.invulnerable=0; garden.stagger=0
	var monkey: GardenMonkey=garden.monkeys[0]
	monkey.global_position=garden.player.global_position+Vector3(0,0,-1.3)
	garden.visual.rotation=Vector3.ZERO; garden.gadget=1; garden.begin_swing()
	for i: int in 30: garden._tick_swing(1.0/60.0)
	check(monkey.captured,"directional swept net captures")
	check(garden.captured_ids.size()==1,"one capture per swing")
	check(not monkey.capture(),"duplicate capture rejected")
	monkey=garden.monkeys[1]; monkey.global_position=garden.player.global_position+Vector3(0,0,-4)
	garden.swing=-1; garden.begin_swing()
	for i: int in 30: garden._tick_swing(1.0/60.0)
	check(not monkey.captured,"out of range blocked")
	check(not garden.clear_line(Vector3(-19,1,-12),Vector3(-17,1,-12)),"wall blocks sight")
	var observer: GardenMonkey=garden.monkeys[2]
	observer.global_position=Vector3(5,0,5); observer.facing=Vector3.FORWARD
	garden.player.global_position=Vector3(5,0,0)
	observer.tick(0.2); check(observer.alert==1,"visible suspicion yellow")
	observer.tick(0.5); check(observer.alert==2,"confirmed sight red")
	garden.player.global_position=Vector3(0,0,22); observer.tick(4.1)
	check(observer.alert==0,"lost target returns blue")
	observer.stun(); check(is_equal_approx(observer.stunned,1.5),"club stun duration")
	garden.hp=37; garden.invulnerable=0; garden.hurt(20,garden.player.position,true)
	check(is_equal_approx(garden.hp,17),"lava removes two hearts")
	garden.stagger=0; garden.invulnerable=0; garden.gadget=1
	for target: GardenMonkey in garden.monkeys:
		if target.captured: continue
		target.global_position=Vector3(0,0,10)
		garden.player.global_position=Vector3(0,0,11.3); garden.visual.rotation=Vector3.ZERO
		garden.swing=-1; garden.begin_swing()
		for i: int in 31: garden._tick_swing(1.0/60.0)
	check(garden.captured_ids.size()==5 and garden.finished and garden.result_outcome=="victory","all five real net sweeps trigger victory")
	garden.intro=0; garden.pause_game(); check(not garden.active and garden.keys.is_empty(),"pause clears input")
	if not DisplayServer.get_name()=="headless":
		garden.player.position=Vector3(0,0.1,16); garden.pivot.position=Vector3(0,2,16); garden.pivot.rotation=Vector3(-0.25,0,0); garden.pause_panel.hide()
		await get_tree().process_frame; await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/monkey/garden-preview.png")
	garden.queue_free(); await get_tree().process_frame
	print("MONKEY_RESULT passed=%d failed=%d"%[passed,failed]); get_tree().quit(1 if failed>0 else 0)
