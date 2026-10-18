extends Node
var passed:=0
var failed:=0
func check(value: bool,label: String)->void:
	if value: passed+=1
	else: failed+=1;push_error("MONKEY_ACTION_FAIL "+label)
func _ready()->void:
	get_tree().create_timer(90).timeout.connect(func()->void:get_tree().quit(2))
	call_deferred("run")
func run()->void:
	var context:=WorldContext.new();context.initialize(PartyProgress.serialize(),42047,true)
	var habitats: Array[String]=["monkey_garden_region","monkey_garden_hard_region","monkey_garden_mania_region","monkey_garden_despair_region"]
	var counts: Array[int]=[5,10,15,20]
	for index in 4:
		var party: Dictionary={}
		for candidate: Dictionary in context.state.maps.river_bay.parties.values():
			if candidate.habitat_id==habitats[index]: party=candidate;break
		check(not party.is_empty() and party.deployed_units.size()==counts[index],"world count %d"%counts[index])
		if party.is_empty(): continue
		var arena_id: String="monkey_garden"+["","_hard","_mania","_despair"][index]
		var profile: MonkeyProfile=WorldCatalog.arenas[arena_id].encounter.monkey_profile
		check(party.deployed_units[0].level==profile.monkey_level,"world level "+arena_id)
		var g: MonkeyGarden=load("res://features/monkey/garden.tscn").instantiate()
		g.profile=profile;g.snapshot={"player_party_snapshot":context.state.player_party,"enemy_party_snapshots":[party.duplicate(true)],"battle_seed":42}
		add_child(g);await get_tree().physics_frame;g.set_physics_process(false);g.intro=0;g.entry_countdown=0;g.drag_camera=true;g.resume_game()
		check(g.monkeys.size()==counts[index] and g.target_count==counts[index],"snapshot actor count")
		var ids: Dictionary={}
		for monkey: GardenMonkey in g.monkeys: ids[monkey.unit_id]=true
		check(ids.size()==counts[index],"unique settlement identities")
		if index==0:
			g.player.position=Vector3(0,0.1,14);g.yaw=PI/2;g.keys={KEY_W:true}
			for i in 10: g._physics_process(1.0/60)
			check(g.player.velocity.x< -4 and absf(g.player.velocity.z)<0.1,"W follows rotated camera")
			g.begin_swing();var at:=g.player.position
			for i in 10: g._physics_process(1.0/60)
			check(Vector2(g.player.position.x-at.x,g.player.position.z-at.z).length()<0.01,"net locks horizontal movement")
			g.swing=-1;g.equip(0);g.begin_swing();at=g.player.position
			for i in 10:g._physics_process(1.0/60)
			check(Vector2(g.player.position.x-at.x,g.player.position.z-at.z).length()<0.01,"club locks horizontal movement")
			g.pointer_request_left=.01;g.drag_camera=false;g._process(.02)
			check(g.drag_camera and g.camera_fallback.button_pressed,"pointer lock refusal activates usable fallback")
			g.feedback.tick(.1);check(not g.feedback.ring.visible and not g.feedback.visible,"no landing marker or persistent caption")
		if index==3:
			var first:=g.monkeys[0];var second:=g.monkeys[1]
			first.global_position=Vector3(0,0,8);second.global_position=Vector3(1,0,8);first.last_seen=Vector3.ZERO
			first.call_alarm();check(second.alert==1 and second.last_seen==Vector3.ZERO,"alarm shares observed location as suspicion")
			first.stun();var initial_stun:=first.stunned;first.stun();check(first.stunned<initial_stun and first.stunned>=.35,"repeated stun resistance retains opening")
			g.player.position=Vector3(0,0,11.3);g.visual.rotation=Vector3.ZERO;g.gadget=1
			for i in g.monkeys.size():
				for target: GardenMonkey in g.monkeys:
					if not target.captured: target.position=Vector3(18,0,18)
				g.monkeys[i].position=Vector3(0,0,10);g.swing=-1;g.begin_swing()
				for frame in 31:g._tick_swing(1.0/60)
				if i==4:check(not g.finished,"five catches do not clear twenty")
			check(g.finished and g.captured_ids.size()==20,"twenty real net sweeps complete victory")
		g.queue_free();await get_tree().process_frame
	var runtime: Dictionary=context.state.maps.river_bay
	var hard: Dictionary={}
	for party: Dictionary in runtime.parties.values():
		if party.habitat_id==habitats[1]:hard=party;break
	var old_ids: Array=[]
	for i in 5:old_ids.append(hard.deployed_units[i].unit_id)
	hard.deployed_units.resize(5)
	var refresh=load("res://features/monkey/roster_refresh.gd")
	context.state.active_encounter={"test":true}
	check(not refresh.apply(context,runtime) and hard.deployed_units.size()==5,"migration defers reserved encounter")
	context.state.active_encounter={}
	refresh.apply(context,runtime)
	var kept:=true
	for i in 5:kept=kept and hard.deployed_units[i].unit_id==old_ids[i]
	check(kept and hard.deployed_units.size()>=10,"additive migration preserves original IDs")
	check(not refresh.apply(context,runtime),"migration is idempotent")
	print("MONKEY_ACTION_RESULT passed=%d failed=%d"%[passed,failed]);get_tree().quit(1 if failed else 0)
