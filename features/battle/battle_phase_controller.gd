class_name BattlePhaseController
extends Node
## Battle-scoped phase clock. No permanent progress or rewards are owned here.
var game:GameDirector
var pause_left:float=0
var hazard:MonsterPhaseDefinition
var hazard_left:float=0
var pending:Array[Dictionary]=[]
var overlay:CanvasLayer
var saved_camera:Vector2
var changed_scene:String=""
var fog:CanvasLayer
func frozen()->bool: return pause_left>0
func reset()->void:
	if is_instance_valid(game) and is_instance_valid(game.render_root):game.render_root.process_mode=Node.PROCESS_MODE_INHERIT
	pause_left=0; hazard=null; pending.clear(); changed_scene=""
	if is_instance_valid(overlay): overlay.queue_free()
	if is_instance_valid(fog):fog.queue_free()
	fog=null
	overlay=null
func request_death(unit:TacticalUnit)->bool:
	var profile:MonsterPhaseDefinition=unit.definition.death_phase
	if profile==null: return false
	if profile.next_form is UnitDefinition:
		var old_frame:Texture2D
		if profile.presentation!=null and DisplayServer.get_name()!="headless":
			var image:Image=game.get_viewport().get_texture().get_image()
			if image!=null and not image.is_empty():old_frame=ImageTexture.create_from_image(image)
		game.evolve_unit(unit,profile.next_form)
		unit.view.show_entry_pose()
		if profile.battlefield!=null: swap_visual_scene(profile.battlefield)
		if profile.hazard_enabled:
			hazard=profile; hazard_left=maxf(0.1,profile.hazard_interval)
			if profile.presentation!=null:start_fog(profile.presentation)
		if profile.pause_seconds>0:
			pause_left=profile.pause_seconds
			saved_camera=game.camera.position; game.camera.position=Iso.project(unit.position)
			game.render_root.process_mode=Node.PROCESS_MODE_DISABLED
			if profile.presentation!=null:
				var cinematic:BloodMoonTransition=preload("res://features/presentation/blood_moon_transition.tscn").instantiate();game.add_child(cinematic);cinematic.configure(profile.presentation,old_frame,profile.pause_seconds);overlay=cinematic
			else:show_transition(profile.title)
		return true # Same unit / persistent ID, no death event, no early XP.
	if profile.final_spawn is UnitDefinition and profile.final_spawn_count>0:
		pending.append({"data":profile.final_spawn,"team":unit.team,"count":profile.final_spawn_count})
		spawn_pending()
	return false # Original final body dies once; echoes carry no snapshot reward IDs.
func show_transition(title:String)->void:
	if is_instance_valid(overlay): overlay.queue_free()
	overlay=CanvasLayer.new(); overlay.layer=20; game.add_child(overlay)
	var shade:ColorRect=ColorRect.new(); shade.color=Color(0.4,0.01,0.03,0.25); shade.mouse_filter=Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); overlay.add_child(shade)
	var label:Label=Label.new(); label.text=title+"\n血月降臨"; label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",34); label.add_theme_color_override("font_color",Color(1,0.3,0.25))
	label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP); label.offset_left=-400;label.offset_right=400;label.offset_top=80;label.offset_bottom=190
	label.mouse_filter=Control.MOUSE_FILTER_IGNORE; overlay.add_child(label)
func swap_visual_scene(packed:PackedScene)->bool:
	var scene:BattlefieldMap=packed.instantiate()
	var data:Dictionary=BattlefieldCompiler.compile(scene)
	if not data.errors.is_empty() or data.cells!=game.ground.cells or data.blocked!=game.ground.blocked:
		game.message.emit("血月換景未套用：Scene通行幾何不相同，原導航保留。")
		scene.free(); return false
	for child:Node in game.render_root.get_children():
		if child is BattlefieldMap:
			game.render_root.remove_child(child); child.queue_free()
	game.render_root.add_child(scene); ScenerySorting.apply_map(scene)
	game.ground.floor_layer=data.ground
	changed_scene=packed.resource_path
	return true
func spawn_pending()->void:
	for entry:Dictionary in pending:
		while entry.count>0 and game.living_ids(entry.team).size()<60:
			var point:Vector2=Vector2.ZERO; var found:bool=false
			for attempt:int in 100:
				var cell:Vector2i=Vector2i(game.rng.randi_range(2,game.ground.cells.x-3),game.rng.randi_range(2,game.ground.cells.y-3))
				var candidate:Vector2=(Vector2(cell)+Vector2.ONE*0.5)*Iso.CELL
				if game._spawn_is_free(candidate) and not game.ground._navigation_blocked(cell): point=candidate;found=true;break
			if not found: break
			# Phase enemies are ordinary battle actors, not timed summons.
			game.spawn_unit(entry.data,entry.team,point,false)
			entry.count-=1
	pending=pending.filter(func(entry:Dictionary)->bool:return entry.count>0)
func tick(delta:float)->bool:
	if frozen():
		if overlay is BloodMoonTransition:overlay.advance(delta)
		pause_left=maxf(0,pause_left-delta)
		if pause_left<=0:
			game.render_root.process_mode=Node.PROCESS_MODE_INHERIT
			game.camera.position=saved_camera
			if is_instance_valid(overlay): overlay.queue_free()
			overlay=null
		return true # Never spend the cinematic delta on battle/hazard clocks.
	spawn_pending()
	if hazard!=null and game.mode==&"battle":
		hazard_left-=delta
		if hazard_left<=0:
			hazard_left+=maxf(0.1,hazard.hazard_interval)
			for unit:TacticalUnit in game.units.values():
				if not unit.alive() or unit.team not in hazard.hazard_teams: continue
				var amount:float=hazard.hazard_fixed_damage if hazard.hazard_fixed_damage>0 else unit.vitals.max_health*hazard.hazard_max_health_fraction
				if amount>0: unit.vitals.damage_resolved(amount)
	return frozen()

func start_fog(style:BattlePhasePresentation)->void:
	if is_instance_valid(fog):fog.queue_free()
	fog=CanvasLayer.new();fog.layer=1;game.add_child(fog)
	var rect:ColorRect=ColorRect.new();rect.mouse_filter=Control.MOUSE_FILTER_IGNORE;rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material:ShaderMaterial=ShaderMaterial.new();material.shader=preload("res://features/presentation/blood_moon_fog.gdshader")
	material.set_shader_parameter("fog_color",style.fog_color);material.set_shader_parameter("opacity",style.fog_opacity);material.set_shader_parameter("density",style.fog_density);material.set_shader_parameter("speed",style.fog_speed)
	rect.material=material;fog.add_child(rect)
