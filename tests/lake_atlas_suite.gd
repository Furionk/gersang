extends SceneTree
var passed: int = 0
var failed: int = 0
var tests: Array[Dictionary] = []
const OUT: String = "res://artifacts/lake-atlas-repair-2026-10-11/"
func check(ok: bool, caption: String) -> void:
	tests.append({"test":caption,"pass":ok})
	print("PASS | " if ok else "FAIL | ",caption)
	if ok: passed+=1
	else: failed+=1
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var hashes: Dictionary = {"millennium_wolf":"bfedbaf2300e0747f3ecb28b34366dcd88e5c8319c6772384d61e77c8fc392ba","millennium_worm":"2902844f6d01cb59c03004e926f0781f468174b0b4125f3541fe623a4ed0fa15"}
	for id: String in hashes:
		var path: String = "res://features/units/art/"+id+"-v1.png"
		var texture: Texture2D = load(path)
		var layout: SpriteSheetLayout = load("res://features/units/data/layouts/"+id+"_layout.tres")
		check(FileAccess.get_sha256(path)==hashes[id],id+" source PNG unchanged")
		check(layout.valid_for(texture.get_size()),id+" 48 native regions valid")
		var complete: bool = true
		var planted: bool = true
		for row: int in 8:
			for column: int in 6:
				var frame: AtlasTexture = SpriteAtlas.frame(texture,layout,row,column)
				var rect: Rect2i = layout.frame_rects[row*6+column]
				complete=complete and frame.get_size()==Vector2(256,256) and frame.filter_clip and texture.get_image().get_region(rect).get_used_rect().has_area()
				planted=planted and (frame.margin.position+layout.source_pivots[row*6+column]).is_equal_approx(layout.foot_point)
			check(layout.frame_rects[row*6].size.y>=110 and layout.frame_rects[row*6+1].size.y>=110 and layout.frame_rects[row*6+2].size.y>=110,id+" row%d idle/walk not vertically truncated"%row)
		check(complete,id+" all96 atlas properties and visible pixels")
		check(planted,id+" all frame feet align at same canvas point")
		var frames: SpriteFrames = SpriteAtlas.frames(texture,layout)
		var linked: bool = true
		for row: int in 8:
			for state: String in ["idle","walk","attack","cast","dead"]:
				linked=linked and frames.has_animation("%s_%d"%[state,row])
		check(linked,id+" all eight runtime directions/states linked")
	var clone: UnitDefinition = load("res://features/units/data/monsters/millennium_worm_clone.tres")
	check(clone.sprite_layout.resource_path=="res://features/units/data/layouts/millennium_worm_layout.tres","worm clones share repaired native layout")
	var report: Dictionary = {"passed":passed,"failed":failed,"tests":tests}
	var file: FileAccess = FileAccess.open(OUT+"results.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print("LAKE_ATLAS_RESULT ",JSON.stringify(report))
	quit(0 if failed==0 else 1)
