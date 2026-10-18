extends SceneTree
## One-shot raster tile packing and native art assignment. Never a runtime hook.
const ART := "res://features/rainbow/art/"
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var paths: Array[String] = ["res://features/world/data/rainbow_temple.tscn", "res://features/battle/maps/rainbow_temple.tscn"]
	for path: String in paths:
		var scene: Node2D = load(path).instantiate()
		if scene.has_meta("rainbow_art_v1"):
			push_error("Refusing to overwrite authored temple art: " + path); scene.free(); quit(1); return
		scene.free()
	for index: int in paths.size():
		var scene: Node2D = load(paths[index]).instantiate()
		var world: bool = index == 0
		var size: Vector2i = Vector2i(64,32) if world else Vector2i(80,40)
		var layer: TileMapLayer = scene.get_node("Ground/Ground_TileMap" if world else "Ground")
		var old_cells: Array[Vector2i] = layer.get_used_cells()
		var old_coordinates: Dictionary = {}
		for cell: Vector2i in old_cells: old_coordinates[cell] = layer.get_cell_atlas_coords(cell)
		var tile_set: TileSet = layer.tile_set.duplicate(true)
		var source: TileSetAtlasSource = tile_set.get_source(0)
		var path: String = ART + ("temple-64-v1.png" if world else "temple-80-v1.png")
		var image: Image = pack_tiles(size)
		image.save_png(path)
		# Native resource reference is restored after the PNG import, not an embedded texture.
		var texture: ImageTexture = ImageTexture.create_from_image(image)
		texture.resource_name = "temple-raster-import-pending"
		source.texture = texture
		for y: int in 8:
			for x: int in 16:
				var coordinate := Vector2i(x,y+1)
				source.create_tile(coordinate)
				if world:
					var data: TileData = source.get_tile_data(coordinate,0)
					data.set_collision_polygons_count(0,1)
					data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(0,-16),Vector2(32,0),Vector2(0,16),Vector2(-32,0)]))
					data.set_custom_data("blocked", x >= 8)
					data.set_custom_data("visual_kind", "stone")
		# Preserve masks, source IDs and scene geometry. Only the ground's visual atlas changes.
		layer.tile_set = tile_set
		for cell: Vector2i in old_cells:
			var blocked: bool = old_coordinates[cell] == Vector2i(2,0)
			layer.set_cell(cell,0,Vector2i(posmod(cell.x,8)+(8 if blocked else 0),posmod(cell.y,8)+1))
		assert(layer.get_used_cells().size() == old_cells.size())
		var scenery := Node2D.new(); scenery.name = "Scenery"; scene.add_child(scenery); scenery.owner = scene
		scenery.y_sort_enabled = true
		var pillar_texture: Texture2D = load(ART + "pillar-v1.png")
		var columns: PackedInt32Array = PackedInt32Array([12,23] if world else [12,19])
		for x: int in columns:
			var pillar := Sprite2D.new(); pillar.name = "DragonPillar" + str(x)
			scenery.add_child(pillar); pillar.owner = scene
			pillar.texture = pillar_texture
			var cell_size: float = 32.0 if world else 40.0
			pillar.position = Iso.project(Vector2(x+0.5,13.0)*cell_size)
			pillar.offset = Vector2(0,-660)
			pillar.scale = Vector2.ONE * (0.13 if world else 0.16)
			pillar.set_meta("world_scenery_id", "rainbow_dragon_pillar_" + str(x))
			pillar.set_meta("world_scenery_name", "火龍紋石柱")
			pillar.set_meta("scenery_sort_override", ScenerySorting.Mode.DEPTH)
		scene.set_meta("rainbow_art_v1",true)
		var packed := PackedScene.new(); packed.pack(scene)
		var pending_path: String = "res://artifacts/rainbow-content/" + ("world-pending.tscn" if world else "battle-pending.tscn")
		ResourceSaver.save(packed,pending_path)
		# Write a native external texture declaration instead of a huge embedded Image resource.
		var text: String = FileAccess.get_file_as_string(pending_path)
		var image_start: int = text.find('[sub_resource type="Image"')
		var texture_start: int = text.find('[sub_resource type="ImageTexture"',image_start)
		var texture_end: int = text.find("\n[", texture_start+1)
		assert(image_start >= 0 and texture_start >= 0 and texture_end > texture_start)
		var declaration: String = text.substr(texture_start, text.find("\n",texture_start)-texture_start)
		var texture_id: String = declaration.get_slice('id="',1).get_slice('"',0)
		text = text.left(image_start) + text.substr(texture_end+1)
		text = text.replace('SubResource("'+texture_id+'")','ExtResource("rainbow_raster")')
		var at: int = text.find("\n\n")+2
		text = text.insert(at,'[ext_resource type="Texture2D" path="'+path+'" id="rainbow_raster"]\n')
		FileAccess.open(paths[index],FileAccess.WRITE).store_string(text)
		scene.free()
	print("RAINBOW_TERRAIN_AUTHORED native masks preserved; 128 raster variants per tile size")
	quit()

func pack_tiles(size: Vector2i) -> Image:
	var stone: Image = (load(ART + "stone-v1.png") as Texture2D).get_image()
	var lava: Image = (load(ART + "lava-v1.png") as Texture2D).get_image()
	var atlas := Image.create(size.x*16,size.y*9,false,Image.FORMAT_RGBA8)
	for row: int in 9:
		for col: int in (3 if row == 0 else 16):
			var is_lava: bool = col == 2 if row == 0 else col >= 8
			var source: Image = lava if is_lava else stone
			var phase := Vector2(col % 8, maxi(0,row-1))
			for py: int in size.y:
				for px: int in size.x:
					var nx: float = (px+0.5)/size.x-0.5
					var ny: float = (py+0.5)/size.y-0.5
					if absf(nx)+absf(ny)>0.5: continue
					var uv := (phase + Vector2(ny+nx+0.5,ny-nx+0.5))/8.0
					var sample := Vector2i(posmod(int(uv.x*source.get_width()),source.get_width()),posmod(int(uv.y*source.get_height()),source.get_height()))
					atlas.set_pixel(col*size.x+px,row*size.y+py,source.get_pixelv(sample))
	return atlas
