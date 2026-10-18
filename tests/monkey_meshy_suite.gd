extends Node
var failed: int=0
func check(value: bool, label_: String) -> void:
	if not value: failed+=1; push_error("MESHY_FAIL "+label_)
func _ready() -> void:
	var garden: MonkeyGarden=load("res://features/monkey/garden.tscn").instantiate(); add_child(garden)
	await get_tree().process_frame
	garden.set_physics_process(false); garden.intro=0; garden.pause_panel.hide()
	check(garden.presentation.skeleton!=null,"skinned hero")
	check(garden.presentation.right_hand>=0 and garden.presentation.left_hand>=0,"two hand joints")
	for clip: String in ["Idle","NetAttack","FlyerHold","Walk","Run"]:
		check(garden.animation.has_animation(clip),"clip "+clip)
	check(garden.presentation.rotor!=null,"independent rotor")
	check(garden.animation.get_animation("NetAttack").length>=0.49 and garden.animation.get_animation("NetAttack").length<=0.53,"net timing")
	print("MESHY_CLIPS ",garden.animation.get_animation_list())
	garden.pivot.position=garden.player.position+Vector3(0,1.0,0); garden.pivot.rotation=Vector3(-0.12,PI+0.35,0); garden.arm.spring_length=3.3
	for entry: Array in [[1,"Idle",0.0],[1,"NetAttack",0.22],[3,"FlyerHold",0.25],[4,"Idle",0.0],[2,"Idle",0.0],[0,"Idle",0.0]]:
		garden.swing=-1; garden.equip(entry[0]); garden.swing=entry[2] if entry[1]=="NetAttack" else -1.0
		garden.presentation.tick(0.016); garden.animation.play(entry[1]); garden.animation.seek(entry[2],true); garden.animation.advance(0)
		garden.presentation.tick(0.0)
		if garden.swing>=0: garden._tick_swing(0.0)
		check(garden.tools[entry[0]].visible,"equipped model visible")
		if DisplayServer.get_name()!="headless":
			await get_tree().process_frame; await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://artifacts/monkey-meshy/game-%s-%s.png"%[entry[0],entry[1]])
	garden.queue_free(); await get_tree().process_frame
	print("MESHY_RESULT failed=",failed); get_tree().quit(1 if failed>0 else 0)
