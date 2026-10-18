extends SceneTree
## Explicit, one-shot native metadata edit for the user's 2026-10-13 art audit.
## Dry-run by default. Never rewrites PNGs, saves, maps, stats or existing crop rectangles.
const OUT: String="res://artifacts/sprite-motion-2026-10-13/"
const STANDARD: Array[int]=[0,1,2,3,4,5,6,7]
const RIGHT_SOURCE: Array[int]=[0,1,2,1,0,7,6,7]
const LEFT_BACK_SOURCE: Array[int]=[0,1,2,1,0,5,6,5]
const RIGHT_FLIP: Array[bool]=[false,false,false,true,true,true,false,false]
const LEFT_FLIP: Array[bool]=[false,false,false,true,true,false,false,true]
# Every mapping below was reviewed against source art, not guessed from filenames.
const REVIEW: Dictionary={
	"merchant":{}, "elite":{}, "beast":{},
	"guard":{"rows":RIGHT_SOURCE,"flip":RIGHT_FLIP},
	"gunner":{"rows":RIGHT_SOURCE,"flip":RIGHT_FLIP},
	"mage":{"rows":LEFT_BACK_SOURCE,"flip":LEFT_FLIP},
	"healer":{"rows":LEFT_BACK_SOURCE,"flip":LEFT_FLIP},
	"controller":{"rows":LEFT_BACK_SOURCE,"flip":LEFT_FLIP},
	"supplier":{"rows":LEFT_BACK_SOURCE,"flip":LEFT_FLIP,"note":"原圖有格線；新裁切排除細小獨立線段。長袍使用原有露腳姿勢，不生成假腿。"},
	"archer":{"rows":RIGHT_SOURCE,"flip":RIGHT_FLIP},
	"boss":{"rows":RIGHT_SOURCE,"flip":RIGHT_FLIP},
	"spirit":{"rows":RIGHT_SOURCE,"flip":RIGHT_FLIP,"note":"靈體浮行；不假裝有實體踏步。"},
	"ninja":{}, "teppo":{"rows":RIGHT_SOURCE,"flip":RIGHT_FLIP,"attack_rows":RIGHT_SOURCE,"attack_flip":RIGHT_FLIP},
	"kohime_v2":{"rows":RIGHT_SOURCE,"flip":RIGHT_FLIP},
	"malfory":{"rows":STANDARD,"flip":[false,false,false,false,false,false,false,false]},
	"blood_wraith":{"rows":RIGHT_SOURCE,"flip":RIGHT_FLIP},
	"tomb_pyromancer":{"rows":LEFT_BACK_SOURCE,"flip":LEFT_FLIP},
	"shaolin_guardian":{},
	"copper_monk_v2":{"rows":[0,0,1,3,4,5,2,5],"flip":[false,false,false,false,false,false,false,true],"attack_rows":[0,0,1,0,0,5,2,5],"attack_flip":[false,false,false,true,true,false,false,true]},
	"earth_claw_v2":{"rows":STANDARD,"flip":[false,false,false,false,false,false,false,false],"note":"抬爪→刺地→收爪保留；地樁怪不做人形踏步。"},
	"lake_guardian":{"rows":RIGHT_SOURCE,"flip":RIGHT_FLIP},
	"millennium_worm":{"rows":RIGHT_SOURCE,"flip":RIGHT_FLIP,"note":"蠕行使用伸縮姿勢，保留已修復的不规则裁切及邻格排除。"},
	"millennium_wolf":{"rows":RIGHT_SOURCE,"flip":RIGHT_FLIP},
	"millennium_bird":{"rows":[0,1,1,1,0,6,5,6],"flip":[false,false,false,true,true,true,false,false],"note":"原圖缺清楚正南飛行視角；南向使用最近的右下視角，北向改用真正背向列5。需補畫正南視角才能精確到8方向。"},
	"millennium_lord":{"rows":RIGHT_SOURCE,"flip":RIGHT_FLIP}
}
func _initialize() -> void: call_deferred("run")
func clip(action: int,columns: Array,fps: float,loop: bool=false) -> SpriteAnimationClip:
	var result: SpriteAnimationClip=SpriteAnimationClip.new()
	result.action=action; result.columns=PackedInt32Array(columns); result.fps=fps; result.loop=loop
	if action==3: result.instant_start_frame=1
	return result
func save_preserving_uid(resource: Resource,path: String) -> void:
	var id: int=ResourceLoader.get_resource_uid(path) if FileAccess.file_exists(path) else -1
	assert(ResourceSaver.save(resource,path)==OK)
	if id!=-1: assert(ResourceSaver.set_uid(path,id)==OK)
func run() -> void:
	var write: bool="--apply-reviewed" in OS.get_cmdline_user_args()
	DirAccess.make_dir_recursive_absolute(OUT)
	if write and FileAccess.file_exists(OUT+"applied.json"):
		push_error("Already applied. Preserve subsequent artist edits; do not rerun."); quit(1); return
	var sheets: Dictionary={}; var changes: Array[Dictionary]=[]
	for unit: UnitDefinition in UnitResourcePaths.definitions():
		var texture: Texture2D=SpriteAtlas.texture_for(unit)
		if texture==null: continue
		var key: String=texture.resource_path
		if not sheets.has(key): sheets[key]={"texture":texture,"units":[],"layout":unit.sprite_layout}
		sheets[key].units.append(unit)
	for key: String in sheets:
		var info: Dictionary=sheets[key]; var texture: Texture2D=info.texture
		var representative: UnitDefinition=info.units[0]
		var layout: SpriteSheetLayout=info.layout
		var id: String=layout.resource_path.get_file().trim_suffix("_layout.tres") if layout!=null else str(representative.id)
		assert(REVIEW.has(id),"Unreviewed sheet: "+key)
		var rule: Dictionary=REVIEW[id]
		var path: String=layout.resource_path if layout!=null else "res://features/units/data/layouts/"+id+"_layout.tres"
		var fresh: bool=layout==null
		if fresh:
			layout=SpriteSheetLayout.new(); layout.source_size=Vector2i(texture.get_size())
			var original_canvas: Vector2=SpriteAtlas.canvas_size(texture,null)
			layout.frame_size=Vector2i(original_canvas); layout.foot_point=Vector2(original_canvas.x*0.5,original_canvas.y*0.87)
			var image: Image=texture.get_image()
			for row: int in 8:
				for column: int in 6:
					var start: Vector2i=Vector2i(column*image.get_width()/6,row*image.get_height()/8)
					var end: Vector2i=Vector2i((column+1)*image.get_width()/6,(row+1)*image.get_height()/8)
					var used: Rect2i=AtlasSilhouetteBounds.meaningful(image.get_region(Rect2i(start,end-start)),true)
					layout.frame_rects.append(Rect2i(start+used.position,used.size))
					layout.source_pivots.append(Vector2(original_canvas.x*0.5-used.position.x,used.size.y-2))
		else: layout=layout.duplicate(true)
		layout.source_texture=texture
		if rule.has("rows"): layout.direction_rows.assign(rule.rows)
		if rule.has("flip"): layout.mirrored_directions.assign(rule.flip)
		# Existing user-authored Clips are not overwritten by a broad migration.
		assert(layout.animations.is_empty(),"Existing authored animation: "+path)
		layout.animations.append(clip(0,[0],2,true))
		var walk_columns: Array=[1,0,2,0]
		var walk_fps: float=8.0
		if id in ["millennium_bird","millennium_lord","spirit"]: walk_columns=[1,2,0,2]; walk_fps=7.0
		if id in ["lake_guardian","millennium_worm","earth_claw_v2"]: walk_fps=6.0
		layout.animations.append(clip(1,walk_columns,walk_fps,true))
		var attack_columns: Array=[0,3,0]; var attack_fps: float=12.0
		if id=="earth_claw_v2": attack_columns=layout.attack_columns; attack_fps=layout.attack_fps
		if id=="copper_monk_v2": attack_columns=[0,3,4,0]; attack_fps=16.0
		var attack: SpriteAnimationClip=clip(2,attack_columns,attack_fps)
		if rule.has("attack_rows"): attack.direction_rows=PackedInt32Array(rule.attack_rows); attack.mirrored_directions.assign(rule.attack_flip)
		layout.animations.append(attack)
		layout.animations.append(clip(3,[0,4,0],12))
		layout.animations.append(clip(4,[5],3))
		assert(layout.valid_for(Vector2i(texture.get_size())),"Invalid reviewed layout: "+path)
		var unit_paths: Array[String]=[]
		for unit: UnitDefinition in info.units: unit_paths.append(unit.resource_path)
		changes.append({"source":key,"layout":path,"new_layout":fresh,"units":unit_paths,"rows":layout.direction_rows,"mirrors":layout.mirrored_directions,"walk_columns":walk_columns,"walk_fps":walk_fps,"note":rule.get("note","")})
		if write:
			save_preserving_uid(layout,path)
			if fresh:
				for original: UnitDefinition in info.units:
					var updated: UnitDefinition=original.duplicate()
					updated.sprite_layout=layout
						save_preserving_uid(updated,original.resource_path)
		print("SPRITE_REVIEW ",id," units=",unit_paths.size()," new=",fresh)
	var file: FileAccess=FileAccess.open(OUT+("applied.json" if write else "plan.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"sheets":changes,"count":changes.size(),"written":write,"source_pngs_unchanged":true},"\t")); file.close()
	print("SPRITE_REVIEW_RESULT sheets=",changes.size()," written=",write)
	quit()
