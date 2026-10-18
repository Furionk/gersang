extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/terrain/native_tiles"))
	var link: bool = "--link" in OS.get_cmdline_user_args()
	for id: String in ["river_bay","qingling_town","well_1","well_2"]:
		for suffix: String in ["terrain","masks"]:
			var path: String = "res://features/world/data/tiles/%s_%s.tres" % [id,suffix]
			var png: String = "res://art/terrain/native_tiles/%s_%s.png" % [id,suffix]
			var set: TileSet = load(path) as TileSet
			var source: TileSetAtlasSource = set.get_source(0) as TileSetAtlasSource
			if link:
				source.texture = load(png) as Texture2D
				if source.texture==null or ResourceSaver.save(set,path)!=OK: quit(1); return
			else:
				if source.texture.get_image().save_png(png)!=OK: quit(1); return
			print("LINK " if link else "EXPORT ",path)
	quit()
