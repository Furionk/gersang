extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var viewport:=SubViewport.new(); viewport.size=Vector2i(128,128); viewport.transparent_bg=true; viewport.own_world_3d=true; viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS; root.add_child(viewport)
	var model: Node3D=load("res://features/monkey/assets/monkey.glb").instantiate(); viewport.add_child(model)
	var camera:=Camera3D.new(); camera.projection=Camera3D.PROJECTION_ORTHOGONAL; camera.size=2.8; camera.position=Vector3(0,1.6,4); viewport.add_child(camera); camera.look_at(Vector3(0,0.9,0)); camera.current=true
	var light:=DirectionalLight3D.new(); light.rotation_degrees=Vector3(-30,-30,0); light.light_energy=0.8; viewport.add_child(light)
	var env:=WorldEnvironment.new(); env.environment=Environment.new(); env.environment.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR; env.environment.ambient_light_color=Color.WHITE; env.environment.ambient_light_energy=0.4; viewport.add_child(env)
	var animation: AnimationPlayer=GardenMonkey.find_animation(model)
	var sheet:=Image.create(768,1024,false,Image.FORMAT_RGBA8)
	for row: int in 8:
		model.rotation.y=-PI/2-float(row)*PI/4
		for column: int in 6:
			animation.play("Walking" if column in [1,2] else "Idle"); animation.seek(0.1 if column==1 else 0.4 if column==2 else 0,true); animation.pause()
			await process_frame; await RenderingServer.frame_post_draw
			sheet.blit_rect(viewport.get_texture().get_image(),Rect2i(0,0,128,128),Vector2i(column*128,row*128))
	assert(sheet.get_used_rect().size!=Vector2i.ZERO,"Rendered atlas must contain visible pixels")
	assert(sheet.save_png("res://features/monkey/assets/monkey_world.png")==OK)
	var layout:=SpriteSheetLayout.new(); layout.source_size=Vector2i(768,1024); layout.frame_size=Vector2i(128,128); layout.foot_point=Vector2(64,110)
	for row: int in 8:
		for col: int in 6:
			layout.frame_rects.append(Rect2i(col*128,row*128,128,128)); layout.source_pivots.append(Vector2(64,110))
	assert(ResourceSaver.save(layout,"res://features/monkey/data/world_layout.tres")==OK)
	for i: int in 5:
		var unit: UnitDefinition=load("res://features/monkey/data/monkey_%d.tres"%i); unit.sprite_layout=layout; unit.world_sprite_scale=0.7
		assert(ResourceSaver.save(unit,unit.resource_path)==OK)
	viewport.queue_free(); await process_frame; print("MONKEY_WORLD_ART_OK"); quit()
