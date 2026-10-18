class_name MonkeyGarden
extends Node3D
signal completed(outcome: String, hp: float, captured_ids: Array[String])
@export var profile: MonkeyProfile = preload("res://features/monkey/data/default.tres")
var snapshot: Dictionary = {}
@onready var layout: MonkeyLevelLayout = $LevelLayout
var player: CharacterBody3D
var visual: Node3D
var animation: AnimationPlayer
var presentation := MonkeyMeshyPresentation.new()
var pivot: Node3D
var camera: Camera3D
var arm: SpringArm3D
var tool_root: Node3D
var tools: Array[Node3D] = []
var monkeys: Array[GardenMonkey] = []
var captured_ids: Array[String] = []
var hp: float = 100
var max_hp: float = 100
var safe_point := Vector3(0,0.1,16)
var keys: Dictionary = {}
var active: bool = false
var finished: bool = false
var sneaking: bool = false
var using_tool: bool = false
var aiming: bool = false
var drag_camera: bool = false
var gadget: int = 1
var previous_gadget: int = 0
var queued_gadget: int = -1
var swing: float = -1
var swing_direction := Vector3.FORWARD
var previous_tip: Vector3
var swing_hit: bool = false
var invulnerable: float = 0
var stagger: float = 0
var jump_buffer: float = 0
var coyote: float = 0
var jumps: int = 0
var flyer_left: float = 1.5
var hoop_charge: float = 0
var yaw: float = 0
var pitch: float = -0.3
var elapsed: float = 0
var intro: float = 1.2
var radar_tick: float = 0
var performance_time: float = 0
var performance_frames: int = 0
var performance_label: Label
var status: Label
var hint: Label
var tool_label: Label
var pause_panel: PanelContainer
var pause_title: Label
var resume_button: Button
var result_outcome: String = ""
var time_left: float=0.0
var timed_out: bool=false
var timer_label: Label
var scroll: VictoryScroll
var scroll_left: float=0.0
var started: bool=false
var entry_countdown: float=3.0
var entry_paused: bool=false
var hud: Control
var pointer_was_locked: bool=false
var pointer_request_left: float=-1.0
var camera_fallback: CheckButton
var target_count: int=5
var feedback: MonkeyNetFeedback
var tone: AudioStreamPlayer
const TOOL_NAMES: Array[String] = ["電擊棒","捕猴網","猴子雷達","飛天螺旋槳","極速呼拉圈"]

func _ready() -> void:
	time_left=profile.time_limit
	drag_camera=false
	safe_point=layout.spawn(); yaw=layout.intro_yaw
	if not snapshot.is_empty():
		var first: Dictionary = snapshot.player_party_snapshot.deployed_units[0]
		hp=float(first.current_hp); max_hp=float(first.resolved_stats.health)
	player=CharacterBody3D.new(); player.name="Catcher"; player.collision_layer=4; player.collision_mask=1
	add_child(player); player.position=safe_point
	var collider := CollisionShape3D.new(); var capsule := CapsuleShape3D.new()
	capsule.radius=0.33; capsule.height=1.65; collider.shape=capsule; collider.position.y=0.83; player.add_child(collider)
	visual=Node3D.new(); player.add_child(visual); visual.rotation.y=yaw
	var character: Node3D=load("res://features/monkey/assets/meshy/hero.glb").instantiate(); visual.add_child(character)
	character.rotation.y=PI; animation=GardenMonkey.find_animation(character)
	pivot=Node3D.new(); add_child(pivot)
	arm=SpringArm3D.new(); arm.spring_length=5.5; arm.collision_mask=1; arm.margin=0.2
	pivot.add_child(arm); camera=Camera3D.new(); arm.add_child(camera); camera.current=true; camera.fov=65
	tool_root=Node3D.new(); visual.add_child(tool_root); tool_root.position=Vector3(0.75,1.3,-0.35)
	if layout.legacy_garden:
		get_node("Sun").light_energy=0.65
		get_node("GardenEnvironment").environment.ambient_light_energy=0.3
		for liquid: String in ["River","Lava"]:
			var surface: MeshInstance3D=get_node(liquid).get_child(0)
			var material:=ShaderMaterial.new(); material.shader=preload("res://features/monkey/data/liquid.gdshader")
			if liquid=="Lava":
				material.set_shader_parameter("deep_color",Color("a62e20")); material.set_shader_parameter("foam_color",Color("ffbd3e"))
			surface.material_override=material
	NavigationServer3D.map_set_cell_height(get_world_3d().navigation_map,0.2)
	presentation.setup(self,character); _build_hud()
	tone=AudioStreamPlayer.new(); add_child(tone)
	var ids: Array[String]=[]
	var kinds: Array[int]=[]
	if not snapshot.is_empty():
		for party: Dictionary in snapshot.enemy_party_snapshots:
			for member: Dictionary in party.deployed_units:
				ids.append(member.unit_id); kinds.append(int(String(member.definition_id).trim_prefix("garden_monkey_")))
	target_count=ids.size() if not ids.is_empty() else profile.monkey_count
	for i: int in target_count:
		var monkey := GardenMonkey.new(); monkey.name="Monkey%d"%i; monkey.kind=kinds[i] if i<kinds.size() else i%5; monkey.arena=self
		monkey.unit_id=ids[i] if i<ids.size() else "demo_monkey_%d"%i
		add_child(monkey); monkey.global_position=layout.home(monkey.kind); monkey.home=monkey.global_position
		monkey.spawn_index=i
		monkey.needs_spawn_spread=monkeys.any(func(other: GardenMonkey)->bool: return other.kind==monkey.kind)
		monkey.path_points=layout.route(monkey.kind)
		monkeys.append(monkey)
	get_window().focus_exited.connect(pause_game)
	feedback=MonkeyNetFeedback.new(); feedback.arena=self; add_child(feedback)
	update_hud()

func _build_tools() -> void:
	for i: int in 5:
		var root:=Node3D.new(); tool_root.add_child(root); tools.append(root)
		var material:=StandardMaterial3D.new(); material.albedo_color=[Color.CYAN,Color("ecdcad"),Color("89e2b3"),Color("f1cb54"),Color("ff9853")][i]
		var stick:=MeshInstance3D.new(); var cylinder:=CylinderMesh.new(); cylinder.top_radius=0.035; cylinder.bottom_radius=0.035; cylinder.height=1
		stick.mesh=cylinder; stick.material_override=material; stick.rotation.x=PI/2; stick.position.z=-0.5; root.add_child(stick)
		if i in [1,2,4]:
			var ring:=MeshInstance3D.new(); var torus:=TorusMesh.new(); torus.inner_radius=0.38 if i==1 else 0.25; torus.outer_radius=0.43 if i==1 else 0.31
			ring.mesh=torus; ring.material_override=material; ring.position.z=-1; root.add_child(ring)
			if i==1:
				for j: int in 5:
					var thread:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3(0.6,0.015,0.015); thread.mesh=box; thread.material_override=material; thread.position=Vector3(0,0,-1+(j-2)*0.12); root.add_child(thread)
		if i==3:
			var blade:=MeshInstance3D.new(); var box:=BoxMesh.new(); box.size=Vector3(1.8,0.06,0.22); blade.mesh=box; blade.material_override=material; blade.position.y=1; root.add_child(blade)
		root.visible=i==gadget

func _build_hud() -> void:
	var layer:=CanvasLayer.new(); layer.layer=30; add_child(layer)
	status=Label.new(); status.position=Vector2(24,20); status.add_theme_font_size_override("font_size",24); layer.add_child(status)
	tool_label=Label.new(); tool_label.position=Vector2(24,60); layer.add_child(tool_label)
	performance_label=Label.new(); performance_label.position=Vector2(24,90); layer.add_child(performance_label)
	timer_label=Label.new(); timer_label.add_theme_font_size_override("font_size",28); layer.add_child(timer_label)
	scroll=VictoryScroll.new(); scroll.title="出陣"; scroll.size=Vector2(340,96); layer.add_child(scroll); scroll.hide()
	hint=Label.new(); hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT); hint.position=Vector2(24,-75); layer.add_child(hint)
	hint.text="WASD 移動 · 滑鼠鏡頭 · 左鍵工具 · 右鍵朝向\nSpace 二段跳 · Ctrl 潛行 · 1–5／滾輪換裝 · Q 道具選擇 · Esc 暫停"
	hud=preload("res://features/monkey/monkey_hud.tscn").instantiate(); hud.arena=self; layer.add_child(hud)
	status.hide(); tool_label.hide(); timer_label.hide(); performance_label.hide()
	pause_panel=PanelContainer.new(); pause_panel.position=Vector2(350,170); pause_panel.custom_minimum_size=Vector2(520,230); layer.add_child(pause_panel)
	var column:=VBoxContainer.new(); column.add_theme_constant_override("separation",14); pause_panel.add_child(column)
	pause_title=Label.new(); pause_title.text="庭園捕猴\n點擊開始捕猴"; pause_title.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; column.add_child(pause_title)
	resume_button=Button.new(); resume_button.text="開始／繼續"; resume_button.pressed.connect(resume_game); column.add_child(resume_button)
	var retreat:=Button.new(); retreat.text="撤退返回河灣"; retreat.pressed.connect(func()->void: finish("retreat")); column.add_child(retreat)
	var shake:=CheckButton.new(); shake.text="鏡頭震動"; shake.button_pressed=profile.camera_shake; shake.toggled.connect(func(value:bool)->void: profile=profile.duplicate(); profile.camera_shake=value); column.add_child(shake)
	var fallback:=CheckButton.new(); camera_fallback=fallback; fallback.text="內嵌瀏覽器：右鍵拖曳鏡頭"; fallback.button_pressed=drag_camera; fallback.toggled.connect(func(value:bool)->void: drag_camera=value); column.add_child(fallback)
	if not layout.legacy_garden:
		var credit:=AcceptDialog.new(); credit.title="村莊素材與授權"; credit.dialog_text="村莊環境素材：Free Fantasy Medieval Houses — EmacEArt\n原始場景與素材：Maciej EmacArt / EmacEArt\n捕猴玩法整合及 Web 適配：巨箱5.0 專案\n\nEmacEArt Asset License：允許個人／商業遊戲使用及修改。\n禁止獨立素材轉售或再分發。署名非強制。"; layer.add_child(credit)
		credit.add_button("作者素材頁",false,"source")
		credit.custom_action.connect(func(_action:StringName)->void: OS.shell_open("https://emaceart.itch.io/free-fantasy-medieval-houses-and-props-pack"))
		var credits:=Button.new(); credits.text="關於／村莊素材製作名單"; credits.pressed.connect(func()->void: credit.popup_centered()); column.add_child(credits)
	pause_panel.hide()
	for label: Label in [status,tool_label,hint,performance_label]:
		label.add_theme_color_override("font_outline_color",Color(0.04,0.08,0.08,0.9))
		label.add_theme_constant_override("outline_size",5)

func _process(_delta: float) -> void:
	if pointer_request_left>=0:
		pointer_request_left-=_delta
		if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED: pointer_request_left=-1
		elif pointer_request_left<=0:
			drag_camera=true
			if camera_fallback: camera_fallback.button_pressed=true
	if is_instance_valid(pause_panel):
		pause_panel.position=(get_viewport().get_visible_rect().size-pause_panel.size)*0.5
		hint.position=Vector2(24,get_viewport().get_visible_rect().size.y-135)
		hint.visible=active and gadget==2 and using_tool
		timer_label.position=Vector2(get_viewport().get_visible_rect().size.x-360,24)
		timer_label.text="%s  %02d:%02d"%[profile.zone_name,int(ceil(time_left))/60,int(ceil(time_left))%60]
		timer_label.modulate=Color("ff6254") if time_left<=15 else Color("ffda78")
		scroll.position=(get_viewport().get_visible_rect().size-scroll.size)*0.5+Vector2(0,-100)
	if feedback: feedback.tick(_delta if active else 0.0)
	if scroll_left>0:
		scroll_left-=_delta
		if scroll_left<=0: scroll.hide()
	if active and not finished:
		performance_time+=_delta; performance_frames+=1
		performance_label.text="%d FPS"%Engine.get_frames_per_second()
		if performance_time>=10:
			print("MONKEY_WEB_PERF frames=",performance_frames," seconds=",performance_time," average_fps=",performance_frames/performance_time)
			performance_time=0; performance_frames=0

func update_hud() -> void:
	status.text="庭園捕猴   %d / 5     ♥ %.1f / %.1f"%[captured_ids.size(),hp/10,max_hp/10]
	tool_label.text="1 電擊棒   2 捕猴網   3 雷達   4 螺旋槳   5 呼拉圈     裝備："+TOOL_NAMES[gadget]
	if gadget!=2: hint.text="WASD 移動 · 滑鼠鏡頭 · 左鍵工具 · 右鍵朝向\nSpace 二段跳 · Ctrl 潛行 · 1–5／滾輪換裝 · Q 道具選擇 · Esc 暫停"

func resume_game() -> void:
	if finished:
		completed.emit(result_outcome,hp,captured_ids); return
	if intro>0: return
	if entry_paused and entry_countdown>0:
		entry_paused=false; pause_panel.hide(); return
	entry_countdown=0
	entry_paused=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE if drag_camera or (OS.has_feature("web") and not started) else Input.MOUSE_MODE_CAPTURED
	active=true; pause_panel.hide(); keys.clear(); using_tool=false
	if OS.has_feature("web") and not drag_camera and started: pointer_request_left=0.35
	if not started:
		started=true
	if drag_camera: hint.text="WASD 移動 · 右鍵拖曳／方向鍵鏡頭 · 左鍵工具\nSpace 二段跳 · Ctrl 潛行 · 1–5 換裝 · Esc 暫停"

func pause_game() -> void:
	entry_paused=true
	if hud: hud.wheel_open=false; hud.countdown_text=""
	active=false; keys.clear(); using_tool=false; aiming=false; jump_buffer=0
	pointer_was_locked=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	if is_instance_valid(pause_panel) and intro<=0 and not finished:
		pause_title.text="已暫停 · 點擊繼續捕猴"; pause_panel.show()

func open_wheel() -> void:
	if not active or finished: return
	active=false; keys.clear(); using_tool=false; aiming=false; jump_buffer=0
	hud.preview=gadget; hud.wheel_open=true; pointer_was_locked=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func close_wheel(commit: bool) -> void:
	if not hud.wheel_open: return
	hud.wheel_open=false
	if commit: equip(hud.preview)
	resume_game()

func _input(event: InputEvent) -> void:
	if hud and hud.wheel_open:
		hud.wheel_input(event); get_viewport().set_input_as_handled(); return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_ESCAPE:
		pause_game(); get_viewport().set_input_as_handled(); return
	if not active: return
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT and not drag_camera and Input.mouse_mode!=Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode=Input.MOUSE_MODE_CAPTURED; pointer_request_left=0.35
		get_viewport().set_input_as_handled(); return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed and Input.mouse_mode==Input.MOUSE_MODE_VISIBLE:
		var hit: int=hud.hud_hit(event.position)
		if hit>=0:
			if hit==5: open_wheel()
			else: equip(hit)
			get_viewport().set_input_as_handled(); return
	if event is InputEventMouseMotion and (Input.mouse_mode==Input.MOUSE_MODE_CAPTURED or (drag_camera and aiming)):
		yaw-=event.relative.x*profile.mouse_sensitivity; pitch=clampf(pitch-event.relative.y*profile.mouse_sensitivity,-1.1,0.25)
	elif event is InputEventKey:
		keys[event.physical_keycode]=event.pressed
		if event.pressed and not event.echo:
			if event.physical_keycode==KEY_SPACE: jump_buffer=0.12
			if event.physical_keycode>=KEY_1 and event.physical_keycode<=KEY_5: equip(event.physical_keycode-KEY_1)
			if event.physical_keycode==KEY_Q: open_wheel()
	elif event is InputEventMouseButton:
		if event.button_index==MOUSE_BUTTON_LEFT:
			using_tool=event.pressed
			if event.pressed and gadget<2: begin_swing()
		elif event.button_index==MOUSE_BUTTON_RIGHT: aiming=event.pressed
		elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_UP: equip((gadget+1)%5)
		elif event.pressed and event.button_index==MOUSE_BUTTON_WHEEL_DOWN: equip((gadget+4)%5)
	get_viewport().set_input_as_handled()

func equip(index: int) -> void:
	if swing>=0: queued_gadget=index; return
	previous_gadget=gadget; gadget=index; hoop_charge=0
	for i: int in tools.size(): tools[i].visible=i==gadget
	update_hud()

func begin_swing() -> void:
	if swing>=0 or stagger>0: return
	swing=0; swing_hit=false; swing_direction=-visual.global_basis.z
	player.velocity.x=0; player.velocity.z=0; jump_buffer=0; hoop_charge=0
	previous_tip=net_tip(0.0) if gadget==1 else player.global_position+Vector3.UP+swing_direction*0.7
	beep(230 if gadget==0 else 430,0.045)

func clear_line(from: Vector3,to: Vector3) -> bool:
	var query:=PhysicsRayQueryParameters3D.create(from,to,1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()

func stable_ground(at: Vector3) -> bool:
	for offset: Vector3 in [Vector3.ZERO,Vector3(0.55,0,0),Vector3(-0.55,0,0),Vector3(0,0,0.55),Vector3(0,0,-0.55)]:
		var query:=PhysicsRayQueryParameters3D.create(at+offset+Vector3.UP*0.25,at+offset-Vector3.UP*0.2,1)
		var hit: Dictionary=get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty() or hit.normal.y<0.85: return false
	return true

func _physics_process(delta: float) -> void:
	if intro>0:
		if not layout.legacy_garden and NavigationServer3D.map_get_iteration_id(get_world_3d().navigation_map)==0: return
		for monkey: GardenMonkey in monkeys: monkey.spread_spawn()
		intro-=delta; pivot.position=layout.intro_position().lerp(player.position+Vector3(0,1.4,0),clampf(1-intro/1.2,0,1)); pivot.rotation=Vector3(-0.3,yaw+intro*0.5,0)
		if intro<=0 and entry_paused: pause_game()
		return
	if entry_countdown>0 and not entry_paused and not finished:
		entry_countdown=maxf(0,entry_countdown-delta)
		hud.countdown_text=str(int(ceil(entry_countdown))) if entry_countdown>0 else "開始！"
		if entry_countdown<=0:
			resume_game()
			get_tree().create_timer(0.65).timeout.connect(func()->void: if is_instance_valid(hud): hud.countdown_text="")
		return
	if not active or finished: return
	if Input.mouse_mode==Input.MOUSE_MODE_CAPTURED: pointer_was_locked=true
	elif not drag_camera and pointer_was_locked:
		pointer_was_locked=false; pause_game(); return
	tick_clock(delta)
	if finished: return
	elapsed+=delta; invulnerable=maxf(0,invulnerable-delta); stagger=maxf(0,stagger-delta)
	sneaking=keys.get(KEY_CTRL,false)
	if drag_camera:
		yaw+=(float(keys.get(KEY_LEFT,false))-float(keys.get(KEY_RIGHT,false)))*delta*1.8
		pitch=clampf(pitch+(float(keys.get(KEY_UP,false))-float(keys.get(KEY_DOWN,false)))*delta,-1.1,0.25)
	var input:=Vector2(float(keys.get(KEY_D,false))-float(keys.get(KEY_A,false)),float(keys.get(KEY_S,false))-float(keys.get(KEY_W,false))).limit_length(1)
	var direction:=Basis(Vector3.UP,yaw)*Vector3(input.x,0,input.y)
	if using_tool and gadget==4: hoop_charge=minf(0.35,hoop_charge+delta)
	else: hoop_charge=maxf(0,hoop_charge-delta*2)
	var speed: float=profile.sneak_speed if sneaking else profile.run_speed*(1.6 if hoop_charge>=0.35 else 1.0)
	if stagger<=0:
		var motion_rate: float=profile.acceleration if direction.length()>0.1 else profile.braking
		player.velocity.x=move_toward(player.velocity.x,direction.x*speed,motion_rate*delta) if swing<0 else 0.0
		player.velocity.z=move_toward(player.velocity.z,direction.z*speed,motion_rate*delta) if swing<0 else 0.0
		if swing<0:
			if aiming: visual.rotation.y=rotate_toward(visual.rotation.y,yaw,profile.turn_rate*delta)
			elif direction.length()>0.1: visual.rotation.y=rotate_toward(visual.rotation.y,atan2(-direction.x,-direction.z),profile.turn_rate*delta)
	jump_buffer=maxf(0,jump_buffer-delta)
	if player.is_on_floor():
		coyote=0.12; jumps=0; flyer_left=1.5
		if layout.damage_at(player.position)==0 and stable_ground(player.position): safe_point=player.position+Vector3.UP*0.25
	else: coyote=maxf(0,coyote-delta)
	if jump_buffer>0 and swing<0 and stagger<=0 and (coyote>0 or jumps<2):
		player.velocity.y=8; jumps+=1; coyote=0; jump_buffer=0; beep(350,0.05)
	player.velocity.y-=22*delta
	if using_tool and gadget==3 and flyer_left>0 and stagger<=0:
		flyer_left-=delta; player.velocity.y=maxf(player.velocity.y,3.5 if flyer_left>0.7 else -1.5)
	var was_grounded: bool=player.is_on_floor()
	player.move_and_slide()
	if not was_grounded and player.is_on_floor(): beep(110,0.04)
	var hazard_damage: float=layout.damage_at(player.global_position)
	if hazard_damage>0:
		hurt(hazard_damage,player.position-Vector3.UP,true); player.global_position=safe_point; player.velocity=Vector3.ZERO
	_tick_swing(delta)
	for monkey: GardenMonkey in monkeys: monkey.tick(delta)
	# Pulsing pressure trap with a visible anticipation ring.
	var trap: Node3D=get_node_or_null("Trap")
	if trap!=null:
		trap.scale=Vector3.ONE*(1+0.12*sin(elapsed*4))
		if fmod(elapsed,3.0)>2.35 and player.position.distance_to(trap.position)<1.5: hurt(10,trap.position)
	if gadget==2 and using_tool: _radar(delta)
	var goal: Vector3=player.position+Vector3.UP*1.4
	pivot.position=pivot.position.lerp(goal,1-exp(-delta*14)); pivot.rotation=Vector3(pitch,yaw,0)
	camera.fov=lerpf(camera.fov,72 if hoop_charge>=0.35 else 65,delta*5)
	camera.h_offset=sin(elapsed*90)*0.06 if stagger>0 and profile.camera_shake else 0
	visual.visible=invulnerable<=0 or fmod(elapsed,0.12)>0.03
	presentation.tick(delta)

func _tick_swing(delta: float) -> void:
	if swing<0: return
	swing+=delta
	var phase: float=clampf((swing-0.12)/0.16,0,1)
	tool_root.rotation=Vector3.ZERO if gadget==1 else Vector3(0,lerpf(-0.8,0.8,phase),0)
	var tip: Vector3=net_tip(phase) if gadget==1 else player.global_position+Vector3.UP+swing_direction.rotated(Vector3.UP,lerpf(-0.65,0.65,phase))*1.35
	if swing>=0.12 and swing<=0.28 and not swing_hit:
		for monkey: GardenMonkey in monkeys:
			if monkey.captured: continue
			var center: Vector3=monkey.global_position+Vector3.UP*0.8
			var nearest: Vector3=Geometry3D.get_closest_point_to_segment(center,previous_tip,tip)
			var offset: Vector3=monkey.global_position-player.global_position
			var in_sweep: bool=nearest.distance_to(center)<=0.55 and net_can_reach(monkey) if gadget==1 else nearest.distance_to(center)<=0.65 and offset.length()<=profile.net_reach and offset.normalized().dot(swing_direction)>0.25 and clear_line(player.global_position+Vector3.UP,center)
			if in_sweep:
				swing_hit=true
				if gadget==1:
					if monkey.capture():
						captured_ids.append(monkey.unit_id); beep(900,0.15); update_hud()
						feedback.flash("捕捉成功！")
						if captured_ids.size()==target_count: finish("victory")
				else: monkey.stun(); beep(170,0.1)
				break
	previous_tip=tip
	if swing>=0.5:
		if gadget==1 and not swing_hit: feedback.flash("揮空")
		swing=-1; tool_root.rotation.y=0
		if queued_gadget>=0:
			var next: int=queued_gadget; queued_gadget=-1; equip(next)

func _radar(delta: float) -> void:
	radar_tick-=delta
	var nearest: float=1000
	var heading: Vector3=-camera.global_basis.z; heading.y=0; heading=heading.normalized()
	for monkey: GardenMonkey in monkeys:
		if monkey.captured: continue
		var offset: Vector3=monkey.position-player.position
		if offset.normalized().dot(heading)>0.7: nearest=minf(nearest,offset.length())
	hint.text="雷達："+("轉動鏡頭搜尋訊號" if nearest>100 else "前方訊號 · "+("很近" if nearest<6 else "遠處"))
	if nearest<100 and radar_tick<=0:
		radar_tick=clampf(nearest/25.0,0.12,1.2)
		beep(1000-nearest*15,0.05)

func hurt(amount: float, source: Vector3, hazard: bool=false) -> void:
	if finished or (invulnerable>0 and not hazard): return
	if not hazard and player.position.distance_to(source)>3: return
	hp=maxf(0,hp-amount); stagger=0.45; invulnerable=1.45
	var away: Vector3=player.position-source; away.y=0; away=away.normalized()
	player.velocity=away*6+Vector3.UP*4; swing=-1; using_tool=false
	beep(90,0.12); update_hud()
	for monkey: GardenMonkey in monkeys:
		if not monkey.captured and monkey.position.distance_to(player.position)<12:
			monkey.alert=2; monkey.suspicion=1; monkey.last_seen=player.position; monkey.lost_time=0
	if hp<=0: finish("defeat")

func finish(outcome: String) -> void:
	if finished: return
	finished=true; active=false; result_outcome=outcome; keys.clear(); using_tool=false
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
	pause_title.text=("時間到 · 挑戰失敗" if timed_out else {"victory":"%d 隻全部捕捉！"%target_count,"defeat":"體力耗盡","retreat":"撤退"}[outcome])+"\n正在保存結果…"
	if outcome=="victory":
		var closeup:=create_tween().set_parallel(true)
		closeup.tween_property(arm,"spring_length",3.0,0.65).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		closeup.tween_property(pivot,"rotation:y",visual.rotation.y+PI,0.8)
	resume_button.text="重試保存／返回"; pause_panel.show()
	completed.emit(outcome,hp,captured_ids)

func tick_clock(delta: float) -> void:
	if not active or finished: return
	time_left=maxf(0,time_left-delta)
	if time_left<=0:
		timed_out=true; finish("retreat")

func net_center() -> Vector3:
	var forward: Vector3=swing_direction if swing>=0 else -visual.global_basis.z
	return player.global_position+forward*1.35+Vector3.UP*0.8

func net_tip(phase_: float) -> Vector3:
	return net_center()+Vector3.UP*lerpf(1.4,-0.45,phase_)

func net_can_reach(monkey: GardenMonkey) -> bool:
	if monkey.captured: return false
	var center: Vector3=monkey.global_position+Vector3.UP*0.8
	var offset: Vector3=center-net_center()
	return Vector2(offset.x,offset.z).length()<=0.55 and absf(offset.y)<=0.55 and player.position.distance_to(monkey.position)<=profile.net_reach and clear_line(player.position+Vector3.UP,center)

func show_scroll(title_: String, seconds: float) -> void:
	# Reuse the same parchment/wood component as ordinary Gersang victories.
	for child: Node in scroll.get_children():
		if child is Label: child.text=title_
	scroll.show(); scroll_left=seconds

func settlement_succeeded(outcome: String) -> void:
	pause_panel.hide()
	show_scroll("勝利" if outcome=="victory" else "時間到" if timed_out else "敗北" if outcome=="defeat" else "撤退",3.0)

func settlement_failed(reason: String) -> void:
	pause_title.text="保存未完成，進度仍保留\n"+reason

func beep(frequency: float, duration: float) -> void:
	var stream:=AudioStreamWAV.new(); stream.format=AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate=22050
	var samples: int=int(duration*22050); var bytes:=PackedByteArray(); bytes.resize(samples*2)
	for i: int in samples:
		var value: int=int(sin(float(i)*frequency*TAU/22050)*2200*(1-float(i)/samples))
		bytes.encode_s16(i*2,value)
	stream.data=bytes; tone.stream=stream; tone.play()

func _exit_tree() -> void:
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE
