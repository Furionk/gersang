class_name SpriteAtlas
extends RefCounted
const PATTERNS: Dictionary = {"idle":[0,0],"walk":[1,2],"attack":[3,0],"cast":[4,0],"dead":[5]}
static var cache: Dictionary = {}
static func texture_for(data: UnitDefinition) -> Texture2D:
	if data.sprite_layout!=null and data.sprite_layout.source_texture!=null: return data.sprite_layout.source_texture
	return load(data.sprite_path) as Texture2D if not data.sprite_path.is_empty() and ResourceLoader.exists(data.sprite_path) else null
static func source_row(layout: SpriteSheetLayout, direction: int, state: String = "idle") -> int:
	return layout.row_for(state,direction) if layout!=null else direction
static func mirrored(layout: SpriteSheetLayout, direction: int, state: String = "idle") -> bool:
	return layout!=null and layout.mirror_for(state,direction)
static func canvas_size(texture: Texture2D, layout: SpriteSheetLayout) -> Vector2:
	return Vector2(layout.frame_size) if layout!=null else Vector2(texture.get_width()/6.0,texture.get_height()/8.0)
static func foot(texture: Texture2D, layout: SpriteSheetLayout) -> Vector2:
	var extent: Vector2 = canvas_size(texture,layout)
	return layout.foot_point if layout!=null else Vector2(extent.x*0.5,extent.y*0.87)
static func frame(texture: Texture2D, layout: SpriteSheetLayout, row: int, column: int, state: String = "idle") -> AtlasTexture:
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = texture
	atlas.filter_clip = true
	if layout==null:
		var cell: Vector2 = canvas_size(texture,null)
		# Integer boundaries avoid fractional UV drift, even for non-divisible art.
		var start: Vector2i = Vector2i(Vector2(column,row)*cell)
		var end: Vector2i = Vector2i(Vector2(column+1,row+1)*cell)
		atlas.region = Rect2(start,end-start)
	else:
		var index: int = source_row(layout,row,state)*layout.columns+column
		atlas.region = Rect2(layout.frame_rects[index])
		atlas.margin = Rect2(layout.foot_point-layout.source_pivots[index],Vector2(layout.frame_size)-atlas.region.size)
	return atlas
static func frames(texture: Texture2D, layout: SpriteSheetLayout = null) -> SpriteFrames:
	var key: String = texture.resource_path+str(texture.get_rid())
	if layout!=null:
		if not layout.valid_for(Vector2i(texture.get_width(),texture.get_height())):
			push_error("Invalid sprite layout: "+layout.resource_path+" / "+"；".join(layout.issues_for(Vector2i(texture.get_width(),texture.get_height()))))
			return SpriteFrames.new()
		key += "|"+str(layout.signature())
	if cache.has(key): return cache[key]
	var result: SpriteFrames = SpriteFrames.new()
	result.remove_animation(&"default")
	for row: int in 8:
		for state: String in PATTERNS:
			var animation: StringName = StringName("%s_%d" % [state,row])
			result.add_animation(animation)
			result.set_animation_speed(animation,layout.fps_for(state) if layout!=null else 6.0 if state=="walk" else 3.0)
			result.set_animation_loop(animation,layout.loop_for(state) if layout!=null else state in ["walk","idle"])
			var columns: PackedInt32Array=layout.columns_for(state) if layout!=null else PackedInt32Array(PATTERNS[state])
			for index: int in columns.size(): result.add_frame(animation,frame(texture,layout,row,columns[index],state),layout.duration_for(state,index) if layout!=null else 1.0)
	cache[key] = result
	return result
