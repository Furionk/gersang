class_name GardenMonkey
extends CharacterBody3D
var arena: Node3D
var kind: int = 0
var unit_id: String = ""
var home: Vector3
var path_points: Array[Vector3] = []
var waypoint: int = 0
var alert: int = 0
var suspicion: float = 0.0
var lost_time: float = 0.0
var stunned: float = 0.0
var captured: bool = false
var last_seen: Vector3
var facing: Vector3 = Vector3.FORWARD
var model: Node3D
var animator: AnimationPlayer
var lamp: MeshInstance3D
var lamp_material: StandardMaterial3D
var navigator: NavigationAgent3D
var attack_clock: float = 0.0
var attack_direction: Vector3 = Vector3.FORWARD
var attack_hit: bool = false
var jump_phase: float = -1.0
var jump_from: Vector3
var jump_to: Vector3
var age: float = 0.0
var decision_left: float=0.0
var burst_left: float=0.0
var dodge_cooldown: float=0.0
var flee_target: Vector3
var observed_velocity: Vector3 = Vector3.ZERO
var burst_cooldown_left: float = 0.0
var recovery_left: float = 0.0
var dodge_pending: float = -1.0
var attack_cooldown: float = 0.0
var jump_cooldown: float = 0.0
var blocked_time: float = 0.0
var gaze_clock: float = 0.0
var hearing_clock: float = 0.0
var spawn_index: int=0
var needs_spawn_spread: bool=false
var temperament: float=1.0
var alarm_left: float=0.0
var feint_left: float=0.0
var frenzy_left: float=0.0
var frenzy_cooldown: float=8.0
var stun_count: int=0
var rank_label: Label3D
var random:=RandomNumberGenerator.new()
const COLORS: Array[Color] = [Color("e8c45a"),Color("528fe6"),Color("e26253"),Color("aa82e6"),Color("65b58a")]

func _ready() -> void:
	collision_layer = 2; collision_mask = 1
	var collider := CollisionShape3D.new()
	var shape := CapsuleShape3D.new(); shape.radius = 0.36; shape.height = 1.3
	collider.shape = shape; collider.position.y = 0.65; add_child(collider)
	model = Node3D.new(); add_child(model)
	var mesh: Node3D = load("res://features/monkey/assets/monkey.glb").instantiate()
	model.add_child(mesh)
	# Exported character is normalized by the asset preparation pass.
	mesh.scale = Vector3.ONE * 0.75
	animator = find_animation(mesh)
	var cap := MeshInstance3D.new(); var cap_mesh := CylinderMesh.new()
	cap_mesh.top_radius = 0.22; cap_mesh.bottom_radius = 0.3; cap_mesh.height = 0.12
	cap.mesh = cap_mesh; cap.position.y = 1.5
	var material := StandardMaterial3D.new(); material.albedo_color = COLORS[kind]; cap.material_override = material
	model.add_child(cap)
	lamp = MeshInstance3D.new(); var sphere := SphereMesh.new(); sphere.radius = 0.12; sphere.height = 0.24
	lamp.mesh = sphere; lamp.position.y = 1.7
	lamp_material = StandardMaterial3D.new(); lamp_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lamp_material.albedo_color=Color("48aaff")
	lamp.material_override = lamp_material; model.add_child(lamp)
	navigator = NavigationAgent3D.new(); navigator.path_desired_distance = 0.4; navigator.target_desired_distance = 0.6; add_child(navigator)
	home = position; last_seen = home
	random.seed=absi(hash(unit_id))+int(arena.snapshot.get("battle_seed",1234))
	temperament=random.randf_range(0.92,1.12)
	frenzy_cooldown=random.randf_range(5,12)
	rank_label=Label3D.new(); rank_label.font=load("res://art/fonts/NotoSansCJKtc-Regular.otf")
	rank_label.text="Lv.%d"%arena.profile.monkey_level; rank_label.font_size=28; rank_label.pixel_size=0.006
	rank_label.position.y=2.05; rank_label.billboard=BaseMaterial3D.BILLBOARD_ENABLED
	model.add_child(rank_label)
	play_clip("Idle")

static func find_animation(root: Node) -> AnimationPlayer:
	if root is AnimationPlayer: return root
	for child: Node in root.get_children():
		var found := find_animation(child)
		if found != null: return found
	return null

func play_clip(clip: String) -> void:
	if animator == null: return
	for key: StringName in animator.get_animation_list():
		if String(key).get_file() == clip or String(key).ends_with(clip):
			if animator.current_animation != key:
				animator.get_animation(key).loop_mode = Animation.LOOP_LINEAR
				animator.play(key,0.15)
			return

func sees(point: Vector3) -> bool:
	var offset: Vector3 = point - global_position
	if offset.length() > arena.profile.sight_range: return false
	var gaze: Vector3 = facing
	# A brief glance checks the last known threat; it still requires FOV and LOS.
	if alert==2 and gaze_clock<0.24:
		gaze=last_seen-global_position; gaze.y=0; gaze=gaze.normalized()
	offset.y=0
	if offset.length()>0.01 and gaze.dot(offset.normalized())<cos(deg_to_rad(arena.profile.sight_degrees*0.5)): return false
	return arena.clear_line(global_position+Vector3.UP,point+Vector3.UP)

func perceive(delta: float) -> bool:
	gaze_clock=fmod(gaze_clock+delta,arena.profile.look_back_interval)
	hearing_clock=maxf(0,hearing_clock-delta)
	var seen: bool=sees(arena.player.global_position)
	if seen:
		last_seen=arena.player.global_position
		observed_velocity=arena.player.velocity; observed_velocity.y=0
		lost_time=0; suspicion=minf(arena.profile.confirmation_seconds,suspicion+delta)
		var confirmed: bool=suspicion>=arena.profile.confirmation_seconds or global_position.distance_to(last_seen)<2.0
		if confirmed and alert!=2:
			decision_left=0
			call_alarm()
		alert=2 if confirmed or alert==2 else 1
	elif alert>0:
		lost_time+=delta
		if lost_time>=arena.profile.search_seconds:
			alert=0; suspicion=0; observed_velocity=Vector3.ZERO
		elif lost_time>arena.profile.search_seconds*0.65:
			alert=1; suspicion=maxf(0,suspicion-delta*0.5)
	if not seen and alert<2 and hearing_clock<=0 and not arena.sneaking:
		var distance: float=global_position.distance_to(arena.player.global_position)
		if arena.player.velocity.length()>2 and distance<arena.profile.hearing_range and arena.clear_line(global_position+Vector3.UP,arena.player.global_position+Vector3.UP):
			# Hearing starts investigation; it cannot instantly confirm a target.
			last_seen=arena.player.global_position; alert=1; lost_time=0; hearing_clock=0.75
	return seen

func call_alarm() -> void:
	if alarm_left>0 or arena.profile.alarm_radius<=0: return
	alarm_left=3.0
	for other: GardenMonkey in arena.monkeys:
		if other==self or other.captured or other.stunned>0 or other.alert==2: continue
		if global_position.distance_to(other.global_position)>arena.profile.alarm_radius: continue
		if not arena.clear_line(global_position+Vector3.UP,other.global_position+Vector3.UP): continue
		other.last_seen=last_seen; other.observed_velocity=observed_velocity
		other.alert=1; other.suspicion=arena.profile.confirmation_seconds*0.75; other.lost_time=0
		other.facing=(last_seen-other.global_position).normalized(); other.decision_left=0

func spread_spawn() -> void:
	if not needs_spawn_spread: return
	var map: RID=get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(map)==0: return
	needs_spawn_spread=false
	if kind==3:
		if not path_points.is_empty(): global_position=path_points[(spawn_index/5)%path_points.size()]
	else:
		for attempt in 16:
			var offset:=Vector3.FORWARD.rotated(Vector3.UP,random.randf()*TAU)*random.randf_range(3,10)
			var candidate:=NavigationServer3D.map_get_closest_point(map,arena.layout.constrain(home+offset))
			var path:=NavigationServer3D.map_get_path(map,arena.safe_point,candidate,true)
			if path.is_empty() or path[-1].distance_to(candidate)>0.5 or candidate.distance_to(home)<1.5 or arena.layout.damage_at(candidate)>0: continue
			var occupied:=false
			for other: GardenMonkey in arena.monkeys:
				if other!=self and other.global_position.distance_to(candidate)<1.0: occupied=true; break
			if not occupied: global_position=candidate; break
	home=global_position; last_seen=home

func jump_clear(from: Vector3, to: Vector3) -> bool:
	var previous:=from+Vector3.UP*0.7
	for step in range(1,17):
		var t: float=step/16.0
		var point:=from.lerp(to,t)+Vector3.UP*(sin(t*PI)*2+0.7)
		if not arena.clear_line(previous,point): return false
		previous=point
	return true

func update_lamp() -> void:
	lamp_material.albedo_color=[Color("48aaff"),Color("ffcf46"),Color("ff4146")][alert]
	var pulse: float=0.15*sin(age*(14 if alert==2 else 3))
	if attack_clock>0 and attack_clock<0.6: pulse=0.45*absf(sin(age*22))
	lamp.scale=Vector3.ONE*(1+pulse)

func tick(delta: float) -> void:
	if captured: return
	spread_spawn()
	alarm_left=maxf(0,alarm_left-delta); feint_left=maxf(0,feint_left-delta)
	frenzy_left=maxf(0,frenzy_left-delta); frenzy_cooldown-=delta
	if arena.layout.damage_at(global_position)>0:
		global_position=home; velocity=Vector3.ZERO; jump_phase=-1; decision_left=0
	age+=delta; decision_left-=delta
	burst_left=maxf(0,burst_left-delta); burst_cooldown_left=maxf(0,burst_cooldown_left-delta)
	recovery_left=maxf(0,recovery_left-delta); dodge_cooldown=maxf(0,dodge_cooldown-delta)
	attack_cooldown=maxf(0,attack_cooldown-delta); jump_cooldown=maxf(0,jump_cooldown-delta)
	stunned=maxf(0,stunned-delta)
	if stunned>0:
		velocity.x=0; velocity.z=0; model.rotation.z=sin(age*18)*0.15
		update_lamp(); play_clip("Idle"); velocity.y-=22*delta; move_and_slide(); return
	var seen: bool=perceive(delta)
	if seen and alert==2 and arena.profile.difficulty>=2 and frenzy_cooldown<=0:
		frenzy_left=random.randf_range(1.4,2.4); frenzy_cooldown=random.randf_range(6,11); call_alarm()
	rank_label.text=("狂暴 " if frenzy_left>0 else "")+"Lv.%d"%arena.profile.monkey_level
	rank_label.modulate=Color("ff6955") if frenzy_left>0 else Color.WHITE
	update_lamp(); model.rotation.z=sin(age*18)*0.07 if frenzy_left>0 else 0
	if jump_phase>=0:
		jump_phase+=delta/arena.profile.jump_seconds
		global_position=jump_from.lerp(jump_to,minf(1,jump_phase))+Vector3.UP*sin(minf(1,jump_phase)*PI)*2
		play_clip("Running"); model.rotation.x=sin(minf(1,jump_phase)*PI)*0.35
		if jump_phase>=1:
			jump_phase=-1; global_position=jump_to; velocity=Vector3.ZERO; jump_cooldown=arena.profile.exhaustion_seconds; model.rotation.x=0
		return
	# Once telegraphed, a pounce commits even if the player leaves the field of view.
	if (kind==2 or (arena.profile.difficulty>=2 and kind==0)) and (attack_clock>0 or (alert==2 and seen and attack_cooldown<=0 and global_position.distance_to(last_seen)<3.4)):
		tick_attack(delta); return
	var target: Vector3=home
	var speed: float=0.8
	if alert==2:
		speed=(7.4 if kind==1 else 5.4)*arena.profile.escape_multiplier*temperament
		speed*=1.0+0.25*float(arena.captured_ids.size())/maxi(1,arena.target_count)
		if frenzy_left>0: speed*=1.18
		if decision_left<=0 or global_position.distance_to(flee_target)<0.8:
			decision_left=arena.profile.decision_seconds*random.randf_range(0.55,1.35)
			flee_target=choose_escape()
			if burst_cooldown_left<=0 and seen:
				burst_left=0.65 if kind==1 else 0.45
				burst_cooldown_left=arena.profile.burst_cooldown
				recovery_left=burst_left+arena.profile.exhaustion_seconds
		if burst_left>0: speed*=arena.profile.burst_multiplier
		elif recovery_left>0: speed*=0.72
		tick_dodge(delta,seen)
		if feint_left>0: speed*=0.12
		target=flee_target
		if kind==4 and not seen and lost_time>0.7 and not arena.clear_line(last_seen+Vector3.UP,global_position+Vector3.UP):
			target=global_position; speed=0
		if kind==3:
			target=global_position; speed=0
			if jump_cooldown<=0 and not path_points.is_empty():
				var destination: Vector3=global_position
				var best: float=-INF
				for point: Vector3 in path_points:
					if point.distance_to(global_position)<1.2 or not jump_clear(global_position,point): continue
					var score: float=point.distance_to(last_seen)
					if score>best: best=score; destination=point
				if destination.distance_to(global_position)>1.2:
					jump_from=global_position; jump_to=destination; jump_phase=0; return
	elif alert==1:
		# Sweep around the remembered location, rather than tracking through a wall.
		target=arena.layout.constrain(last_seen+Vector3(sin(age*1.4),0,cos(age*1.4))*1.4)
		speed=1.8
	else:
		target=home+Vector3(sin(age*0.25),0,cos(age*0.25))
	if kind==3:
		target=global_position; speed=0
	model.rotation.x=0
	var direction: Vector3=target-global_position
	if kind!=3 and NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map)>0:
		if navigator.target_position.distance_to(target)>0.5: navigator.target_position=target
		direction=navigator.get_next_path_position()-global_position
	direction.y=0
	if direction.length()>0.25:
		facing=direction.normalized()
		velocity.x=move_toward(velocity.x,facing.x*speed,delta*30)
		velocity.z=move_toward(velocity.z,facing.z*speed,delta*30)
		model.rotation.y=lerp_angle(model.rotation.y,atan2(-facing.x,-facing.z),delta*9)
		play_clip("Running" if speed>3 else "Walking")
	else:
		velocity.x=0; velocity.z=0
		if alert==1:
			facing=Vector3.FORWARD.rotated(Vector3.UP,age*1.6)
			model.rotation.y=atan2(-facing.x,-facing.z)
		play_clip("Idle_Dance" if kind==0 and alert==0 else "Idle")
	var before: Vector3=global_position
	velocity.y-=22*delta; move_and_slide()
	if alert==2 and speed>0 and global_position.distance_to(before)<delta*0.3:
		blocked_time+=delta
		if blocked_time>0.35:
			decision_left=0; blocked_time=0
			if is_on_floor() and arena.profile.difficulty>0: velocity.y=5.0
	else: blocked_time=0

func tick_dodge(delta: float, seen: bool) -> void:
	if dodge_pending>=0:
		dodge_pending-=delta
		if dodge_pending<=0:
			dodge_pending=-1
			if seen and arena.swing>=0 and arena.swing<0.3:
				flee_target=choose_escape(true); decision_left=0.5; burst_left=0.35
				var dodge_dir: Vector3=(flee_target-global_position).normalized()
				velocity.x=dodge_dir.x*9; velocity.z=dodge_dir.z*9
				if is_on_floor(): velocity.y=4.0
	elif seen and arena.gadget<2 and arena.swing>=0 and arena.swing<0.13 and dodge_cooldown<=0 and kind!=3 and global_position.distance_to(last_seen)<3.8:
		dodge_cooldown=arena.profile.dodge_cooldown_seconds
		if random.randf()<arena.profile.dodge_chance:
			dodge_pending=arena.profile.dodge_reaction*random.randf_range(0.85,1.15)
			if random.randf()<arena.profile.feint_chance: feint_left=dodge_pending*0.8

func tick_attack(delta: float) -> void:
	if attack_clock==0:
		attack_direction=last_seen-global_position; attack_direction.y=0; attack_direction=attack_direction.normalized(); attack_hit=false
	attack_clock+=delta; facing=attack_direction
	model.rotation.y=atan2(-facing.x,-facing.z)
	model.rotation.x=-0.25 if attack_clock<arena.profile.attack_windup else 0.2
	var lunging: bool=attack_clock>=arena.profile.attack_windup and attack_clock<arena.profile.attack_windup+0.25
	velocity.x=attack_direction.x*8 if lunging else 0
	velocity.z=attack_direction.z*8 if lunging else 0
	if lunging and not attack_hit and global_position.distance_to(arena.player.global_position)<1.4 and arena.clear_line(global_position+Vector3.UP,arena.player.global_position+Vector3.UP):
		attack_hit=true; arena.hurt(arena.profile.hit_hp,global_position)
	if attack_clock>=arena.profile.attack_windup+0.25+arena.profile.attack_recovery:
		attack_clock=0; attack_cooldown=maxf(0.45,1.8-arena.profile.difficulty*0.4); decision_left=0; model.rotation.x=0
	play_clip("Running" if lunging else "Idle"); velocity.y-=22*delta; move_and_slide()

func choose_escape(sidestep: bool=false) -> Vector3:
	var predicted: Vector3=last_seen+observed_velocity*arena.profile.prediction_seconds*maxf(0,1-lost_time)
	var away: Vector3=global_position-predicted; away.y=0
	if away.length()<0.1: away=facing
	away=away.normalized()
	var best: Vector3=global_position
	var best_score: float=-INF
	var nav_map: RID=get_world_3d().navigation_map
	var has_nav: bool=NavigationServer3D.map_get_iteration_id(nav_map)>0
	for i: int in 11:
		var angle: float=random.randf_range(-2.3,2.3)
		if sidestep: angle=(1 if i%2==0 else -1)*random.randf_range(0.9,1.5)
		var direction: Vector3=away.rotated(Vector3.UP,angle)
		var candidate: Vector3=global_position+direction*random.randf_range(4,10)
		if not sidestep and kind in [1,4] and i<path_points.size(): candidate=path_points[i]
		candidate=arena.layout.constrain(candidate)
		if has_nav: candidate=NavigationServer3D.map_get_closest_point(nav_map,candidate)
		if not arena.layout.activity_bounds.has_point(arena.layout.to_local(candidate)) or candidate.distance_to(global_position)<1.5 or arena.layout.damage_at(candidate)>0: continue
		var route:=PackedVector3Array([global_position,candidate])
		if has_nav:
			route=NavigationServer3D.map_get_path(nav_map,global_position,candidate,true)
			if route.is_empty() or route[-1].distance_to(candidate)>0.8: continue
		var path_length: float=0
		var closest: float=global_position.distance_to(predicted)
		for j: int in range(1,route.size()):
			path_length+=route[j-1].distance_to(route[j])
			var near: Vector3=Geometry3D.get_closest_point_to_segment(predicted,route[j-1],route[j])
			closest=minf(closest,near.distance_to(predicted))
		var score: float=candidate.distance_to(predicted)-path_length*0.2+random.randf_range(0,1.5+arena.profile.difficulty*1.5)
		if closest<2.5: score-=(2.5-closest)*6
		if not arena.clear_line(last_seen+Vector3.UP,candidate+Vector3.UP): score+=9 if kind==4 else 3
		for other: GardenMonkey in arena.monkeys:
			if other!=self and not other.captured and candidate.distance_to(other.position)<2: score-=3
		if score>best_score: best=candidate; best_score=score
	return best

func stun() -> void:
	if captured: return
	stun_count+=1
	stunned=maxf(0.35,arena.profile.stun_seconds/(1+arena.profile.stun_resistance*mini(stun_count-1,4))); alert=2; suspicion=arena.profile.confirmation_seconds; lost_time=0
	attack_clock=0; attack_cooldown=1.0; dodge_pending=-1; burst_left=0; recovery_left=0; decision_left=0

func capture() -> bool:
	if captured: return false
	captured=true; collision_layer=0; collision_mask=0
	var tween := create_tween().set_parallel(true)
	tween.tween_property(model,"scale",Vector3.ONE*0.01,0.3)
	tween.tween_property(model,"position:y",2.8,0.3)
	return true
