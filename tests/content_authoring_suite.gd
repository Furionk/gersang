extends Node
var passed:int=0
var failed:int=0
var checks:Array[Dictionary]=[]
func check(ok:bool,title:String) -> void:
	checks.append({"pass":ok,"test":title}); print("PASS | " if ok else "FAIL | ",title)
	if ok: passed+=1
	else: failed+=1
static func sample() -> SpriteSheetLayout:
	var layout:SpriteSheetLayout=SpriteSheetLayout.new()
	layout.source_size=Vector2i(256,128); layout.columns=4; layout.rows=4
	layout.frame_size=Vector2i(128,64); layout.foot_point=Vector2(64,56)
	layout.direction_rows=[0,1,2,3,0,1,2,3]
	for row:int in 4:
		for column:int in 4:
			layout.frame_rects.append(Rect2i(column*64,row*32,64,32)); layout.source_pivots.append(Vector2(32,30))
	var sequences:Array=[[0],[1,2,3,2,1],[3,2,1],[0,2,1,3,2,0,3],[3]]
	for i:int in 5:
		var clip:SpriteAnimationClip=SpriteAnimationClip.new(); clip.action=i
		clip.columns=PackedInt32Array(sequences[i]); clip.fps=8+i; clip.loop=i in [0,1]
		layout.animations.append(clip)
	layout.animations[1].frame_durations=PackedFloat32Array([1,2,1,1,1])
	var image:Image=Image.create(256,128,false,Image.FORMAT_RGBA8); image.fill(Color(0.2,0.5,0.8))
	layout.source_texture=ImageTexture.create_from_image(image)
	return layout
func _ready() -> void: call_deferred("run")
func run() -> void:
	var layout:SpriteSheetLayout=sample()
	check(layout.valid_for(layout.source_size),"4 columns/4 source rows valid with 8 output directions")
	var frames:SpriteFrames=SpriteAtlas.frames(layout.source_texture,layout)
	for direction:int in 8:
		for state:String in SpriteAnimationClip.STATES:
			var animation:StringName=StringName("%s_%d"%[state,direction])
			check(frames.get_frame_count(animation)==layout.columns_for(state).size(),"variable frames "+str(animation))
	check(frames.get_frame_duration(&"walk_0",1)==2 and frames.get_animation_speed(&"walk_0")==9,"native SpriteFrames duration and fps")
	var before:SpriteFrames=frames
	layout.animations[1].columns=PackedInt32Array([3,2]); layout.animations[1].frame_durations=PackedFloat32Array()
	frames=SpriteAtlas.frames(layout.source_texture,layout)
	check(frames!=before and frames.get_frame_count(&"walk_0")==2,"nested clip edits invalidate frame cache")
	var bad:SpriteSheetLayout=layout.duplicate(true)
	bad.animations.append(bad.animations[0].duplicate())
	check(not bad.valid_for(bad.source_size),"duplicate action rejected")
	bad=layout.duplicate(true); bad.animations[0].columns=PackedInt32Array([4])
	check(not bad.valid_for(bad.source_size),"out of range columns rejected")
	bad=layout.duplicate(true); bad.animations[0].frame_durations=PackedFloat32Array([0])
	check(not bad.valid_for(bad.source_size),"zero timing rejected")
	for unit:UnitDefinition in UnitResourcePaths.definitions():
		var texture:Texture2D=SpriteAtlas.texture_for(unit)
		check(texture!=null,"texture "+str(unit.id))
		if texture==null: continue
		if unit.sprite_layout!=null: check(unit.sprite_layout.valid_for(Vector2i(texture.get_size())),"legacy layout "+str(unit.id))
		var legacy:SpriteFrames=SpriteAtlas.frames(texture,unit.sprite_layout)
		for state:String in SpriteAnimationClip.STATES:
			var count:int=unit.sprite_layout.columns_for(state).size() if unit.sprite_layout!=null else SpriteAtlas.PATTERNS[state].size()
			check(legacy.get_frame_count(StringName(state+"_0"))==count,"legacy count "+str(unit.id)+"/"+state)
	check(Catalog.trial_entry("kohime").enemy.id==&"kohime_enemy" and Catalog.trial_entry("malfory").enemy==null,"explicit trial enemy references")
	var data:UnitDefinition=UnitDefinition.new(); data.id=&"independent_filename"; data.sprite_layout=layout
	check(SpriteAtlas.texture_for(data)==layout.source_texture,"source Texture reference works without filename convention")
	var report:Dictionary={"passed":passed,"failed":failed,"checks":checks}
	var file:FileAccess=FileAccess.open("res://artifacts/content-authoring-2026-10-12/results.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("CONTENT_AUTHORING_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
