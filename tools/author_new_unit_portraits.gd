extends SceneTree
## Original generated PNGs remain intact; native AtlasTexture regions only.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var failed: bool=false
	for folder: String in ["mercenaries","monsters","summons"]:
		for file: String in DirAccess.get_files_at("res://features/units/data/"+folder):
			if file.get_basename() not in ["kohime","ninja","teppo","earth_claw","kohime_enemy","ninja_enemy","teppo_enemy","earth_claw_enemy","teppo_companion"]: continue
			var path: String="res://features/units/data/"+folder+"/"+file
			var data: UnitDefinition=load(path)
			if data.portrait_texture!=null: continue
			var rect: Rect2i=data.sprite_layout.frame_rects[12]
			var atlas: Texture2D=load(data.sprite_path)
			var portrait: AtlasTexture=AtlasTexture.new(); portrait.atlas=atlas; portrait.filter_clip=true
			portrait.region=Rect2(Vector2(rect.position)+Vector2(rect.size.x*0.25,0),Vector2(rect.size.x*0.5,minf(rect.size.x*0.5,rect.size.y)))
			var standee: AtlasTexture=AtlasTexture.new(); standee.atlas=atlas; standee.filter_clip=true; standee.region=Rect2(rect)
			data.portrait_texture=portrait; data.standee_texture=standee
			if ResourceSaver.save(data,path)!=OK: failed=true
	print("NEW_UNIT_PORTRAITS_RESULT ok=",not failed)
	quit(1 if failed else 0)
