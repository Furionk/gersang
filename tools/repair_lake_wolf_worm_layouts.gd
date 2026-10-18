extends SceneTree
## One-shot native metadata repair. Source PNGs and game/world data stay immutable.
const Bounds: Script = preload("res://features/presentation/atlas_silhouette_bounds.gd")
const OUT: String = "res://artifacts/lake-atlas-repair-2026-10-11/"
func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute(OUT)
	var bands: Dictionary = {
		"millennium_wolf":[0,157,327,501,662,826,1003,1200,1448],
		"millennium_worm":[0,165,330,502,670,827,1018,1210,1448]
	}
	for id: String in bands:
		var path: String = "res://features/units/data/layouts/"+id+"_layout.tres"
		var source: String = "res://features/units/art/"+id+"-v1.png"
		var image: Image = (load(source) as Texture2D).get_image()
		var layout: SpriteSheetLayout = (load(path) as SpriteSheetLayout).duplicate(true)
		if layout.get_meta("lake_atlas_repaired_v1",false):
			print("SKIP artist-owned repaired layout: ",path)
			continue
		assert(image.get_size()==Vector2i(1086,1448))
		var backup: String = OUT+id+"-before.tres.txt"
		if not FileAccess.file_exists(backup):
			var file: FileAccess = FileAccess.open(backup,FileAccess.WRITE)
			file.store_string(FileAccess.get_file_as_string(path)); file.close()
		layout.frame_rects.clear(); layout.source_pivots.clear()
		for row: int in 8:
			for column: int in 6:
				var begin: Vector2i = Vector2i(maxi(0,column*181-18),bands[id][row])
				var end: Vector2i = Vector2i(mini(image.get_width(),(column+1)*181+18),bands[id][row+1])
				var used: Rect2i = Bounds.meaningful(image.get_region(Rect2i(begin,end-begin)),true)
				var rect: Rect2i = Rect2i(begin+used.position,used.size)
				# Explicit source rectangles exclude visible neighbouring tails/glow.
				var limits: Rect2i = Rect2i(Vector2i.ZERO,image.get_size())
				if id=="millennium_wolf":
					if row==1 and column==4: limits.position.y=170; limits.size.y=1448-170
					if row==2 and column==4: limits.position.y=337; limits.size.y=1448-337
					if row==4 and column==3: limits.size.x=724
					if row==4 and column==4: limits.position.x=728; limits.size.x=1086-728
					if row==7 and column==4: limits.size.x=904
					if row==7 and column==5: limits.position.x=915; limits.size.x=1086-915
				elif column==3 and row in [0,7]: limits.size.x=705
				rect=rect.intersection(limits)
				layout.frame_rects.append(rect)
				layout.source_pivots.append(Vector2(column*181+90.5-rect.position.x,rect.size.y-2))
		# Three touching source silhouettes cannot be separated with a rectangular
		# crop. Use the clean same-direction attack pose for that cast frame.
		if id=="millennium_worm":
			for row: int in [0,4,7]:
				layout.frame_rects[row*6+4]=layout.frame_rects[row*6+3]
				layout.source_pivots[row*6+4]=layout.source_pivots[row*6+3]
		assert(layout.valid_for(image.get_size()))
		layout.set_meta("lake_atlas_repaired_v1",true)
		assert(ResourceSaver.save(layout,path)==OK)
		print("LAKE_ATLAS_REPAIRED ",id)
	quit()
