extends Node2D
const OUT: String="res://artifacts/sprite-motion-2026-10-13/"
const COMPASS: Array[String]=["E","SE","S","SW","W","NW","N","NE"]
const REVIEWED_SOURCES: Array[String]=["archer.png","beast.png","blood_wraith-v1.png","boss.png","controller.png","copper_monk-motion-v3.png","earth-claw-v2.png","elite.png","guard.png","gunner.png","healer.png","kohime-v2.png","lake_guardian-v1.png","mage.png","malfory-v1.png","merchant.png","millennium_bird-motion-v3.png","millennium_lord-v1.png","millennium_wolf-v1.png","millennium_worm-v1.png","ninja.png","shaolin_guardian-v1.png","spirit.png","supplier.png","teppo-motion-v2.png","tomb_pyromancer-v1.png"]
var passed: int=0
var failures: Array[String]=[]
var checks: Array[Dictionary]=[]
var definitions: Array[UnitDefinition]=[]
var gallery_unit: UnitDefinition
var director: GameDirector
func check(ok: bool,title: String) -> void:
	checks.append({"pass":ok,"test":title})
	if ok: passed+=1
	else: failures.append(title); push_error("FAIL | "+title)
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(OUT+"gallery")
	get_tree().create_timer(100).timeout.connect(func()->void: get_tree().quit(2))
	call_deferred("run")
func actor_for(data: UnitDefinition) -> TacticalUnit:
	var actor: TacticalUnit=TacticalUnit.new()
	actor.definition=data; actor.director=director
	actor.combat_stats={"speed":data.speed}
	actor.fsm=UnitStateMachine.new(); actor.add_child(actor.fsm)
	actor.statuses=StatusController.new(); actor.add_child(actor.statuses)
	actor.vitals=UnitVitals.new(); actor.vitals.initialize(data); actor.add_child(actor.vitals)
	add_child(actor); actor.set_physics_process(false)
	var view: UnitView=UnitView.new(); add_child(view); view.initialize(actor)
	return actor
func run() -> void:
	director=GameDirector.new(); director.mode=&"battle"
	var seen: Dictionary={}
	for data: UnitDefinition in UnitResourcePaths.definitions():
		var texture: Texture2D=SpriteAtlas.texture_for(data)
		if texture==null or texture.resource_path.get_file() not in REVIEWED_SOURCES: continue # Concurrent new species belong to their own work, not this frozen art review.
		check(data.sprite_layout!=null,"native layout "+str(data.id))
		check(data.sprite_layout!=null and data.sprite_layout.valid_for(Vector2i(texture.get_size())),"valid source bounds "+str(data.id))
		if not seen.has(texture.resource_path): definitions.append(data); seen[texture.resource_path]=true
	check(definitions.size()==REVIEWED_SOURCES.size(),"all 26 requested sheets enumerated; concurrent new species preserved")
	# Exercise the actual world view, not only the shared playback helper.
	# Minimal explicit world party: avoid depending on currently changing ecology/phase authoring.
	var context: WorldContext=WorldContext.new()
	var world_data: UnitDefinition=definitions[0]
	var party: Dictionary={"party_id":"sprite-fixture","representative_path":world_data.resource_path,"life_state":"ACTIVE","position":Vector2.ZERO,"facing":Vector2.DOWN,"path":[],"deployed_units":[{"rated_power":100}],"reserve_units":[],"display_name":"sprite fixture"}
	context.state={"maps":{"river_bay":{"parties":{"sprite-fixture":party}}}}
	var world_view: WorldPartyView=WorldPartyView.new()
	world_view.context=context; world_view.party_id=party.party_id; add_child(world_view)
	party.path=[party.position+Vector2(100,100)]; world_view._process(0)
	DirectionalAnimation.set_phase(world_view.sprite,0.63)
	for direction: int in 8:
		party.facing=Iso.unproject(Vector2.from_angle(direction*PI/4)).normalized(); world_view._process(0)
		check(is_equal_approx(DirectionalAnimation.phase_of(world_view.sprite),0.63),"actual world view phase "+COMPASS[direction])
	world_view.set_process(false); world_view.queue_free()
	for data: UnitDefinition in definitions:
		var texture: Texture2D=SpriteAtlas.texture_for(data)
		var layout: SpriteSheetLayout=data.sprite_layout
		var frames: SpriteFrames=SpriteAtlas.frames(texture,layout)
		if texture.resource_path.contains("-motion-v"):
			check(layout.columns==8 and layout.columns_for("walk")==PackedInt32Array([1,2,3,4]),"four newly painted phases "+str(data.id))
			for direction: int in 8:
				var pose_hashes: Dictionary={}
				for column: int in [1,2,3,4]:
					var rect: Rect2i=layout.frame_rects[layout.row_for("walk",direction)*layout.columns+column]
					pose_hashes[hash(texture.get_image().get_region(rect).get_data())]=true
				check(pose_hashes.size()==4,"four distinct source poses "+str(data.id)+"/"+COMPASS[direction])
		for state: String in SpriteAnimationClip.STATES:
			check(layout.clip_for(state)!=null,"explicit action "+str(data.id)+"/"+state)
			for direction: int in 8:
				var name: StringName=StringName("%s_%d"%[state,direction])
				check(frames.get_frame_count(name)==layout.columns_for(state).size(),"native clip count "+str(data.id)+"/"+str(name))
				for pose: int in frames.get_frame_count(name):
					var atlas: AtlasTexture=frames.get_frame_texture(name,pose) as AtlasTexture
					var index: int=layout.row_for(state,direction)*layout.columns+layout.columns_for(state)[pose]
					check(atlas.region==Rect2(layout.frame_rects[index]) and (atlas.margin.position+layout.source_pivots[index]).is_equal_approx(layout.foot_point),"exact source/pivot "+str(data.id)+"/"+str(name)+"/"+str(pose))
		var actor: TacticalUnit=actor_for(data)
		actor.desired_velocity=Vector2.RIGHT*100
		actor.view._process(0)
		DirectionalAnimation.set_phase(actor.view.sprite,0.63)
		for direction: int in 8:
			actor.facing=Iso.unproject(Vector2.from_angle(direction*PI/4)).normalized()
			actor.view._process(0)
			check(is_equal_approx(DirectionalAnimation.phase_of(actor.view.sprite),0.63),"turn preserves walk phase "+str(data.id)+"/"+COMPASS[direction])
		actor.desired_velocity=Vector2.ZERO
		var target: TacticalUnit=actor_for(data); target.unit_id=13; target.position=actor.position+Vector2(1,0)
		actor._engage(target,1.0/60.0)
		check(actor.view.visual_action=="attack" and actor.view.sprite.frame==0 and actor.shots==0,"real attack-start event is presentation only "+str(data.id))
		target.view.queue_free(); target.queue_free()
		actor.attack_windup_left=-1
		actor.visual_action_started.emit("attack")
		DirectionalAnimation.set_phase(actor.view.sprite,0.95)
		actor.visual_action_started.emit("attack")
		check(actor.view.sprite.frame==0 and actor.view.sprite.frame_progress==0,"repeat attack restarts "+str(data.id))
		actor.visual_action_started.emit("cast")
		actor.view._process(0)
		check(String(actor.view.sprite.animation).begins_with("cast_"),"instant cast retains visual recovery "+str(data.id))
		var instant: SkillDefinition=SkillDefinition.new(); instant.cast_time=0
		actor.active={"skill":instant}; actor.visual_action_started.emit("cast")
		check(actor.view.sprite.frame==layout.clip_for("cast").instant_start_frame,"instant skill skips authored windup "+str(data.id))
		actor.desired_velocity=Vector2.RIGHT*100; actor.view._process(0)
		check(String(actor.view.sprite.animation).begins_with("walk_") and actor.view.visual_action.is_empty(),"move immediately interrupts recovery "+str(data.id))
		actor.view.queue_free(); actor.queue_free()
	# Per-action directions and mirrored edits must invalidate shared preview cache.
	var sample: SpriteSheetLayout=definitions[0].sprite_layout.duplicate(true)
	var signature: int=sample.signature(); sample.mirrored_directions[0]=not sample.mirrored_directions[0]
	check(sample.signature()!=signature,"mirror edits invalidate preview cache")
	var attack: SpriteAnimationClip=sample.clip_for("attack")
	attack.direction_rows=PackedInt32Array([1,1,1,1,1,1,1,1])
	var atlas: AtlasTexture=SpriteAtlas.frames(sample.source_texture,sample).get_frame_texture(&"attack_0",0) as AtlasTexture
	check(atlas.region==Rect2(sample.frame_rects[sample.columns+attack.columns[0]]),"per-action source mapping reaches native SpriteFrames")
	attack.direction_rows=PackedInt32Array([999,1,1,1,1,1,1,1])
	check(not sample.valid_for(sample.source_size),"invalid action direction rejected")
	await live_playback()
	if DisplayServer.get_name()!="headless":
		for data: UnitDefinition in definitions:
			gallery_unit=data; queue_redraw()
			await get_tree().process_frame; await RenderingServer.frame_post_draw
			check(get_viewport().get_texture().get_image().save_png(OUT+"gallery/"+str(data.id)+".png")==OK,"render gallery "+str(data.id))
	director.free()
	var file: FileAccess=FileAccess.open(OUT+("headless-results.json" if DisplayServer.get_name()=="headless" else "render-results.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failures.size(),"failures":failures,"checks":checks,"sheets":definitions.size(),"rendered":DisplayServer.get_name()!="headless"},"\t")); file.close()
	print("SPRITE_MOTION_RESULT passed=",passed," failed=",failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
func live_playback() -> void:
	var old_fps: int=Engine.max_fps
	var old_vsync: DisplayServer.VSyncMode=DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for fps: int in [30,120]:
		Engine.max_fps=fps
		var sprites: Array[AnimatedSprite2D]=[]
		var poses: Array[Dictionary]=[]
		for data: UnitDefinition in definitions:
			var sprite: AnimatedSprite2D=AnimatedSprite2D.new(); sprite.sprite_frames=SpriteAtlas.frames(SpriteAtlas.texture_for(data),data.sprite_layout)
			add_child(sprite); sprite.visible=false
			DirectionalAnimation.play(sprite,"walk",0,data.sprite_layout); sprites.append(sprite); poses.append({})
		var start: int=Time.get_ticks_msec(); var turn: int=0
		while Time.get_ticks_msec()-start<1150:
			await get_tree().process_frame
			turn=(turn+1)%8
			for i: int in sprites.size():
				poses[i][sprites[i].frame]=true
				DirectionalAnimation.play(sprites[i],"walk",turn,definitions[i].sprite_layout)
		for i: int in sprites.size():
			check(poses[i].size()>=3,"continuous turns advance actual frames "+str(definitions[i].id)+" "+str(fps)+"FPS")
			sprites[i].queue_free()
	Engine.max_fps=old_fps; DisplayServer.window_set_vsync_mode(old_vsync)
func _draw() -> void:
	if gallery_unit==null: return
	draw_rect(Rect2(Vector2.ZERO,Vector2(1280,720)),Color("202825"))
	var texture: Texture2D=SpriteAtlas.texture_for(gallery_unit)
	var layout: SpriteSheetLayout=gallery_unit.sprite_layout
	var font: Font=ThemeDB.fallback_font
	draw_string(font,Vector2(15,24),str(gallery_unit.id)+" / native crop + fixed feet / source poses, no interpolated artwork",HORIZONTAL_ALIGNMENT_LEFT,-1,17)
	var states: Array[String]=["idle","walk","walk","walk","walk","attack","cast","dead"]
	var indices: Array[int]=[0,0,1,2,3,1,1,0]
	for direction: int in 8:
		draw_string(font,Vector2(10,80+direction*80),COMPASS[direction],HORIZONTAL_ALIGNMENT_LEFT,-1,16)
		for pose: int in states.size():
			var state: String=states[pose]
			var sequence: PackedInt32Array=layout.columns_for(state)
			var column: int=sequence[mini(indices[pose],sequence.size()-1)]
			var atlas: AtlasTexture=SpriteAtlas.frame(texture,layout,direction,column,state)
			var origin: Vector2=Vector2(120+pose*148,122+direction*80)
			var scale_value: float=0.4
			draw_set_transform(origin,0,Vector2(-scale_value if layout.mirror_for(state,direction) else scale_value,scale_value))
			draw_texture(atlas,-layout.foot_point)
			draw_set_transform(Vector2.ZERO)
			draw_line(origin-Vector2(7,0),origin+Vector2(7,0),Color.GREEN)
			if direction==0: draw_string(font,Vector2(origin.x-45,48),state+str(column),HORIZONTAL_ALIGNMENT_LEFT,-1,14)
