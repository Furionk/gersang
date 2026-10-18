extends Node
var failed: int=0
var passed: int=0
func check(value: bool, label_: String) -> void:
	if value: passed+=1
	else: failed+=1; push_error("DIFFICULTY_FAIL "+label_)
func _ready() -> void:
	var g: MonkeyGarden=load("res://features/monkey/garden.tscn").instantiate()
	add_child(g); await get_tree().physics_frame
	g.set_physics_process(false); g.intro=0
	g.player.position=Vector3(0,0,12); g.visual.rotation=Vector3.ZERO; g.gadget=1
	g.begin_swing()
	var top:=g.net_tip(0); var bottom:=g.net_tip(1)
	check(top.y>bottom.y+1.8 and Vector2(top.x,top.z).distance_to(Vector2(bottom.x,bottom.z))<0.001,"vertical drop without sideways sweep")
	var m: GardenMonkey=g.monkeys[0]
	m.position=g.player.position+Vector3(0,0,-1.35)
	check(g.net_can_reach(m),"marker center catchable")
	m.position.x+=0.7
	check(not g.net_can_reach(m),"outside marker not catchable")
	m.position=g.player.position+Vector3(0,1.0,-1.35)
	check(not g.net_can_reach(m),"wrong height not catchable")
	m.position=g.player.position+Vector3(0,0,1.35)
	check(not g.net_can_reach(m),"behind player not catchable")
	g.swing=-1; g.presentation.tick(0)
	check(g.tool_root.rotation.is_zero_approx(),"idle restores tool pose")
	var hard: MonkeyProfile=load("res://features/monkey/data/hard.tres")
	var mania: MonkeyProfile=load("res://features/monkey/data/mania.tres")
	check(g.profile.time_limit==180 and hard.time_limit==120 and mania.time_limit==90,"three time limits")
	check(g.profile.escape_multiplier<hard.escape_multiplier and hard.escape_multiplier<mania.escape_multiplier,"increasing escape speed")
	check(g.profile.dodge_chance<hard.dodge_chance and hard.dodge_chance<mania.dodge_chance,"increasing evasion")
	for id: String in ["monkey_garden","monkey_garden_hard","monkey_garden_mania"]:
		var arena=load("res://features/world/data/"+id+"_arena.tres")
		check(arena.encounter.monkey_profile!=null,"configured arena "+id)
	g.time_left=2; g.active=false; g.tick_clock(1)
	check(g.time_left==2,"paused clock")
	g.active=true; g.tick_clock(0.5)
	check(g.time_left==1.5,"running clock")
	g.hp=37; g.tick_clock(2)
	check(g.finished and g.timed_out and g.result_outcome=="retreat" and g.hp==37,"timeout preserves wounds without victory")
	g.tick_clock(10); check(g.time_left==0,"timeout stops at zero")
	g.settlement_failed("test")
	check(g.pause_panel.visible,"save failure remains retryable")
	g.settlement_succeeded("retreat")
	check(g.scroll.visible and not g.pause_panel.visible,"saved result uses existing scroll")
	g.queue_free(); await get_tree().process_frame
	print("DIFFICULTY_RESULT passed=%d failed=%d"%[passed,failed]); get_tree().quit(1 if failed else 0)
