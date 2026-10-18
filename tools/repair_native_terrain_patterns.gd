extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var configure: bool = "--configure" in OS.get_cmdline_user_args()
	for id: String in ["river_bay","qingling_town","well_1","well_2"]:
		var scene_path: String = "res://features/world/data/%s.tscn" % id
		var map: WorldMap2D = load(scene_path).instantiate() as WorldMap2D
		var definition: WorldMapDefinition = map.compile_definition()
		for suffix: String in ["terrain","masks"]:
			if not configure: continue
			var path: String = "res://features/world/data/tiles/%s_%s.tres" % [id,suffix]
			var set: TileSet = load(path) as TileSet
			var atlas: TileSetAtlasSource = set.get_source(0) as TileSetAtlasSource
			while set.get_terrains_count(0)>2: set.remove_terrain(0,set.get_terrains_count(0)-1)
			for kind: int in 6:
				for mask: int in 16:
					var data: TileData = atlas.get_tile_data(Vector2i(kind,mask),0)
					data.terrain_set = -1
					if kind>=2: continue
					data.terrain_set = 0
					data.terrain = kind
					var side: int = 0
					for bit: int in 16:
						if data.is_valid_terrain_peering_bit(bit):
							data.set_terrain_peering_bit(bit,kind if mask&(1<<side) else 1-kind)
							side+=1
			# Border tiles need empty (-1) as well as ground/road neighbours.
			# Alternative tiles reuse the same PNG region, avoiding duplicate art.
			for kind: int in 2:
				for code: int in 81:
					var tile: Vector2i = Vector2i(kind,15)
					var alternate: int = atlas.create_alternative_tile(tile)
					var data: TileData = atlas.get_tile_data(tile,alternate)
					data.set_custom_data("blocked",false)
					data.set_custom_data("visual_kind","mask" if suffix=="masks" else "ground" if kind==0 else "road")
					data.set_collision_polygons_count(0,1)
					data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(0,-16),Vector2(32,0),Vector2(0,16),Vector2(-32,0)]))
					data.terrain_set = 0
					data.terrain = kind
					var digits: int = code
					for bit: int in 16:
						if data.is_valid_terrain_peering_bit(bit):
							data.set_terrain_peering_bit(bit,digits%3-1)
							digits/=3
			if ResourceSaver.save(set,path)!=OK: quit(1); return
		if configure: map.free(); continue
		var floor: WorldTileLayer = map.get_node("Ground_TileMap") as WorldTileLayer
		floor.clear()
		floor.update_internals()
		var all: Array[Vector2i] = []
		for y: int in int(ceilf(definition.extent.y/32)):
			for x: int in int(ceilf(definition.extent.x/32)): all.append(Vector2i(x,y))
		floor.set_cells_terrain_connect(all,0,0)
		print("BASE ",id," ",floor.get_used_cells().size())
		var test_data: TileData = (floor.tile_set.get_source(0) as TileSetAtlasSource).get_tile_data(Vector2i(0,3),0)
		var bits: Array = []
		for bit: int in 16:
			if test_data.is_valid_terrain_peering_bit(bit): bits.append([bit,test_data.get_terrain_peering_bit(bit)])
		print("PATTERN ",bits)
		var roads: Dictionary = {}
		for road: PackedVector2Array in definition.roads:
			for i: int in range(1,road.size()):
				var bounds: Rect2 = Rect2(road[i-1],Vector2.ZERO).expand(road[i]).grow(48)
				for y: int in range(int(floorf(bounds.position.y/32)),int(ceilf(bounds.end.y/32))):
					for x: int in range(int(floorf(bounds.position.x/32)),int(ceilf(bounds.end.x/32))):
						var cell: Vector2i = Vector2i(x,y)
						var center: Vector2 = (Vector2(cell)+Vector2.ONE*0.5)*32
						if center.distance_to(Geometry2D.get_closest_point_to_segment(center,road[i-1],road[i]))<40 and Rect2(Vector2.ZERO,definition.extent).has_point(center): roads[cell]=true
		var brush: Array[Vector2i] = []
		brush.assign(roads.keys())
		if not brush.is_empty(): floor.set_cells_terrain_connect(brush,0,1)
		print("FLOOR ",id," actual=",floor.get_used_cells().size()," expected=",all.size())
		if floor.get_used_cells().size()!=all.size(): quit(1); return
		var packed: PackedScene = PackedScene.new()
		if packed.pack(map)!=OK or ResourceSaver.save(packed,scene_path)!=OK: quit(1); return
		map.free()
	quit()
