extends SceneTree
## One-time correction of the initial review's column-space arithmetic; no recutting.
func _initialize()->void:call_deferred("run")
func run()->void:
	for id:String in ["school_dementor","school_dark_elf","school_gatekeeper","school_basilisk","school_cerberus","voldemort_illusion","ganondorf_phantom"]:
		var layout:SpriteSheetLayout=load("res://features/units/data/layouts/"+id+"_layout.tres")
		if layout.has_meta("column_pivots_corrected"):push_error("Already corrected; refuses overwrite "+id);quit(1);return
		assert(layout.has_meta("initial_silhouette_review"))
		for row:int in 8:
			for col:int in range(1,5):layout.source_pivots[row*6+col].x+=col*layout.source_size.x/6
		layout.set_meta("column_pivots_corrected",true);assert(ResourceSaver.save(layout,layout.resource_path)==OK)
		var data:UnitDefinition=load("res://features/units/data/monsters/"+id+".tres")
		data.portrait_texture=SpriteAtlas.frame(layout.source_texture,layout,2,0);data.eyes_texture=data.portrait_texture;data.standee_texture=data.portrait_texture
		assert(ResourceSaver.save(data,data.resource_path)==OK)
		if id=="ganondorf_phantom":
			var echo:UnitDefinition=load("res://features/units/data/monsters/ganondorf_echo.tres")
			echo.portrait_texture=data.portrait_texture;echo.eyes_texture=data.portrait_texture;echo.standee_texture=data.portrait_texture
			assert(ResourceSaver.save(echo,echo.resource_path)==OK)
	print("HOGWARTS_PIVOT_COLUMN_CORRECTION_SAVED original_PNGs_unchanged");quit()
