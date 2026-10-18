extends SceneTree
func _initialize() -> void:
	for id: String in ["millennium_worm","millennium_worm_clone","millennium_bird","millennium_wolf","millennium_lord"]:
		var path: String="res://features/units/data/monsters/"+id+".tres"
		var data: UnitDefinition=load(path)
		if data.portrait_texture!=null: continue
		var atlas: AtlasTexture=AtlasTexture.new(); atlas.atlas=load(data.sprite_path)
		atlas.region=Rect2(data.sprite_layout.frame_rects[12]); atlas.filter_clip=true
		data.portrait_texture=atlas; data.standee_texture=atlas
		assert(ResourceSaver.save(data,path)==OK)
	var flame: SkillDefinition=load("res://features/skills/data/lake_bird_flame.tres")
	flame.effect_data.sprite_grounded=true; flame.effect_data.sprite_foot_ratio=0.9
	assert(ResourceSaver.save(flame,"res://features/skills/data/lake_bird_flame.tres")==OK)
	quit()
