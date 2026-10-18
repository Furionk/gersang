class_name GroundMap
extends Node2D
var terrain: int = 0
var ground_texture: Texture2D
var world_mode: bool = false
var cells: Vector2i = Vector2i(34, 28)
var blocked: Array[Rect2i] = []
var grid: Dictionary = {}
var prop_positions: Array[Vector2] = []
var region: NavigationRegion2D
var floor_layer: TileMapLayer
var map_seed: int = 7471
var dynamic_counts: Dictionary = {}
var walls: Dictionary = {}
var wall_bodies: Dictionary = {}
var air_map: RID
var simulation_parent: Node2D
var exploration_definition: WorldMapDefinition
var scenery_views: Array[WorldSceneryView] = []
var authored_obstacles: Array[Rect2i] = []
var battle_id: String = ""
var authored_battlefield: bool = false
var battle_zones: Array[Dictionary] = []

func build_scene(parent: Node2D, visual_parent: Node2D, scene: BattlefieldMap) -> Dictionary:
	var data: Dictionary = BattlefieldCompiler.compile(scene)
	if not data.errors.is_empty(): return {"ok":false,"error":"\n".join(data.errors)}
	authored_battlefield=true
	cells=data.cells
	blocked.assign(data.blocked)
	battle_zones.assign(data.zones)
	floor_layer=data.ground
	_build_navigation(parent)
	visual_parent.add_child(scene)
	visual_parent.y_sort_enabled=true
	ScenerySorting.apply_map(scene)
	visual_parent.add_child(self)
	return {"ok":true}

func build_exploration(visual_parent: Node2D, definition: WorldMapDefinition) -> void:
	visual_parent.y_sort_enabled=true
	exploration_definition = definition
	terrain = definition.terrain
	world_mode = true
	cells = Vector2i((definition.extent / Iso.CELL).ceil())
	blocked.clear()
	if not definition.native_tile_layers.is_empty():
		for data: WorldTileLayerData in definition.native_tile_layers:
			var native_layer: TileMapLayer = TileMapLayer.new()
			native_layer.name = data.layer_name
			native_layer.tile_set = data.tile_set
			native_layer.tile_map_data = data.cells
			native_layer.position = data.offset
			native_layer.z_index = data.z
			native_layer.collision_enabled = false
			native_layer.navigation_enabled = false
			visual_parent.add_child(native_layer)
			if floor_layer==null: floor_layer = native_layer
	else:
		_build_legacy_exploration_floor(visual_parent)
	visual_parent.add_child(self)
	z_index = -3400
	_build_exploration_props(visual_parent,definition)
	queue_redraw()

func _build_legacy_exploration_floor(visual_parent: Node2D) -> void:
	floor_layer = TileMapLayer.new()
	floor_layer.name = "RegionGround"
	var tiles: TileSet = TileSet.new()
	tiles.tile_size = Vector2i(80,40)
	tiles.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tiles.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = _tile_texture()
	atlas.texture_region_size = Vector2i(80,40)
	atlas.create_tile(Vector2i.ZERO)
	tiles.add_source(atlas,0)
	floor_layer.tile_set = tiles
	for x: int in cells.x:
		for y: int in cells.y:
			floor_layer.set_cell(Vector2i(x,y),0,Vector2i.ZERO)
	floor_layer.position.y = 20
	floor_layer.z_index = -3500
	visual_parent.add_child(floor_layer)

func _build_exploration_props(visual_parent: Node2D, definition: WorldMapDefinition) -> void:
	if not definition.scenery.is_empty():
		for entry: Dictionary in definition.scenery:
			var view: WorldSceneryView = WorldSceneryView.new()
			view.name = "Scenery_"+str(entry["id"])
			view.position = Iso.project(entry["point"])
			visual_parent.add_child(view)
			view.initialize(entry["definition"],entry["point"],entry.get("portal_id",""),entry.get("name",""))
			if view.sprite!=null: view.sprite.transform = entry.get("artwork_basis",Transform2D.IDENTITY)*view.sprite.transform
			view.visible=bool(entry.get("visible",true))
			ScenerySorting.apply_item(view,int(entry.get("sorting_mode",entry.definition.sorting_mode)))
			if view.sprite!=null:
				view.sprite.texture_filter=entry.get("texture_filter",CanvasItem.TEXTURE_FILTER_PARENT_NODE)
				if entry.get("material")!=null: view.sprite.material=entry.material
			scenery_views.append(view)
		for landmark: Dictionary in definition.landmarks:
			if landmark["kind"] in ["bridge","farm","mountain"]:
				var label: Label = Label.new()
				label.text = landmark["name"]
				label.position = Iso.project(landmark["point"])+Vector2(-55,-25)
				visual_parent.add_child(label)
		return
	for blocker: PolygonDomain in definition.blockers:
		var bounds: Rect2 = blocker.bounds()
		if blocker.visual_kind == "water" or bounds.size.x > bounds.size.y * 3:
			continue
		for x: int in range(int(bounds.position.x+40),int(bounds.end.x),100):
			for y: int in range(int(bounds.position.y+40),int(bounds.end.y),100):
				var prop: MapProp = MapProp.new()
				prop.position = Iso.project(Vector2(x,y))
				prop.theme = 0 if blocker.visual_kind == "forest" else 1 if definition.kind != WorldMapDefinition.Kind.DUNGEON else 2
				if blocker.visual_kind == "building": prop.atlas_index = 2
				prop.z_index = 0
				visual_parent.add_child(prop)
	for landmark: Dictionary in definition.landmarks:
		var label: Label = Label.new()
		label.text = landmark["name"]
		label.position = Iso.project(landmark["point"]) + Vector2(-70,-25)
		label.add_theme_font_size_override("font_size",15)
		label.add_theme_color_override("font_color",Color(0.94,0.83,0.55))
		visual_parent.add_child(label)
		if landmark["kind"] in ["town","well"]:
			var prop: MapProp = MapProp.new()
			prop.position = Iso.project(landmark["point"]) + Vector2(0,-80)
			prop.atlas_index = 2 if landmark["kind"] == "town" else 4
			prop.size_multiplier = 0.7 if landmark["kind"] == "town" else 0.4
			prop.z_index = 0
			visual_parent.add_child(prop)
	for portal: Dictionary in definition.portals:
		var label: Label = Label.new()
		label.text = "◆ 入口：" + str(portal["target_map_id"])
		label.position = Iso.project(portal["point"]) + Vector2(-70,-8)
		label.add_theme_color_override("font_color",Color(0.45,0.85,1))
		visual_parent.add_child(label)
	queue_redraw()

func build(simulation_parent: Node2D, visual_parent: Node2D, theme: int, is_world: bool = false) -> void:
	authored_battlefield=false
	battle_zones.clear()
	terrain = theme
	world_mode = is_world
	# Logical cells, not projected screen rectangles, own pathfinding.
	blocked = [Rect2i(13, 7, 4, 7), Rect2i(20, 19, 6, 3)]
	if theme == 1:
		blocked = [Rect2i(14, 0, 3, 11), Rect2i(14, 16, 3, 12), Rect2i(24, 9, 4, 5)]
	elif theme == 2:
		blocked = [Rect2i(6, 7, 5, 5), Rect2i(17, 6, 4, 8), Rect2i(24, 18, 5, 5)]
	if is_world:
		blocked = [Rect2i(11, 5, 5, 7), Rect2i(20, 18, 5, 4)]
	elif not authored_obstacles.is_empty():
		blocked = authored_obstacles.duplicate()
	else:
		# Four connected combat sectors, broad lanes between distinct themed islands.
		blocked = [Rect2i(19,8,3,4),Rect2i(24,20,4,3),Rect2i(9,25,3,3)]
		if theme==1: blocked = [Rect2i(20,3,3,8),Rect2i(20,19,3,6),Rect2i(32,24,4,3)]
		elif theme==2: blocked = [Rect2i(18,5,4,5),Rect2i(26,20,4,5),Rect2i(8,27,4,3)]
	_build_navigation(simulation_parent)
	floor_layer = TileMapLayer.new()
	floor_layer.name = "IsometricGround"
	visual_parent.add_child(floor_layer)
	var tiles: TileSet = TileSet.new()
	tiles.tile_size = Vector2i(80, 40)
	tiles.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	tiles.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	floor_layer.tile_set = tiles
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = _battle_tile_atlas()
	atlas.texture_region_size = Vector2i(80, 40)
	for variant: int in 4: atlas.create_tile(Vector2i(variant,0))
	atlas.get_tile_data(Vector2i.ZERO, 0).texture_origin = Vector2i(0, 0)
	tiles.add_source(atlas, 0)
	var variation: FastNoiseLite = FastNoiseLite.new()
	variation.seed = map_seed
	variation.frequency = 0.16
	for x: int in cells.x:
		for y: int in cells.y:
			var lane: bool = absi(y-15)<=1 or absi(x-29)<=1
			var noise: float = variation.get_noise_2d(x,y)
			var patch: int = 1 if noise < -0.18 else 2 if noise > 0.18 else 0
			floor_layer.set_cell(Vector2i(x, y), 0, Vector2i(3 if lane else patch,0))
	floor_layer.position = Vector2(-40, 0)
	visual_parent.add_child(self)
	z_index = -3400
	floor_layer.z_index = -3500
	queue_redraw()
	for rectangle: Rect2i in blocked:
		for x: int in range(rectangle.position.x, rectangle.end.x, 2):
			for y: int in range(rectangle.position.y, rectangle.end.y, 2):
				prop_positions.append(Iso.project((Vector2(x, y) + Vector2.ONE * 0.5) * Iso.CELL))
	for x: int in range(1,cells.x,2):
		for y: int in [0,cells.y-1]: prop_positions.append(Iso.project((Vector2(x,y)+Vector2.ONE*0.5)*Iso.CELL))
	for y: int in range(2,cells.y-2,2):
		for x: int in [0,cells.x-1]: prop_positions.append(Iso.project((Vector2(x,y)+Vector2.ONE*0.5)*Iso.CELL))
	var props: GroundProps = GroundProps.new()
	props.map = self
	visual_parent.add_child(props)
	if is_world:
		for entry: Array in [[Vector2(140, 180), 2], [Vector2(280, 140), 2], [Vector2(320, 300), 1]]:
			var landmark: MapProp = MapProp.new()
			landmark.position = Iso.project(entry[0])
			landmark.theme = 0
			landmark.atlas_index = int(entry[1])
			landmark.size_multiplier = 0.42
			ScenerySorting.apply_item(landmark)
			visual_parent.add_child(landmark)

func is_blocked(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.y < 0 or cell.x >= cells.x or cell.y >= cells.y:
		return true
	for rectangle: Rect2i in blocked:
		if rectangle.has_point(cell):
			return true
	return false

func _navigation_blocked(cell: Vector2i) -> bool:
	if int(dynamic_counts.get(cell, 0)) > 0:
		return true
	for x: int in range(-1, 2):
		for y: int in range(-1, 2):
			if int(dynamic_counts.get(cell + Vector2i(x, y), 0)) > 0:
				return true
	if is_blocked(cell):
		return true
	# Paths clear the largest configurable body radius at solid corners.
	for rect: Rect2i in blocked:
		if rect.grow(1).has_point(cell):
			return true
	return false

func _build_navigation(parent: Node2D) -> void:
	simulation_parent = parent
	region = NavigationRegion2D.new()
	region.name = "GroundNavigation"
	parent.add_child(region)
	region.navigation_polygon = _ground_polygon()
	air_map = NavigationServer2D.map_create()
	NavigationServer2D.map_set_active(air_map, true)
	var air_region: NavigationRegion2D = NavigationRegion2D.new()
	air_region.name = "AirNavigation"
	parent.add_child(air_region)
	air_region.set_navigation_map(air_map)
	var air_polygon: NavigationPolygon = NavigationPolygon.new()
	air_polygon.vertices = PackedVector2Array([Vector2.ZERO, Vector2(cells.x * Iso.CELL, 0), Vector2(cells) * Iso.CELL, Vector2(0, cells.y * Iso.CELL)])
	air_polygon.add_polygon(PackedInt32Array([0, 1, 2, 3]))
	air_region.navigation_polygon = air_polygon
	for rectangle: Rect2i in blocked:
		var body: StaticBody2D = StaticBody2D.new()
		body.collision_layer = 1
		body.collision_mask = 2
		body.position = (Vector2(rectangle.position) + Vector2(rectangle.size) * 0.5) * Iso.CELL
		parent.add_child(body)
		var collider: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2(rectangle.size) * Iso.CELL
		collider.shape = shape
		body.add_child(collider)

func _ground_polygon() -> NavigationPolygon:
	var polygon: NavigationPolygon = NavigationPolygon.new()
	polygon.agent_radius = 0.0
	var points: PackedVector2Array = PackedVector2Array()
	var indexes: Dictionary = {}
	var polygons: Array[PackedInt32Array] = []
	for x: int in cells.x:
		for y: int in cells.y:
			if _navigation_blocked(Vector2i(x, y)):
				continue
			var quad: PackedInt32Array = PackedInt32Array()
			for offset: Vector2i in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]:
				var key: Vector2i = Vector2i(x, y) + offset
				if not indexes.has(key):
					indexes[key] = points.size()
					points.append(Vector2(key) * Iso.CELL)
				quad.append(int(indexes[key]))
			polygons.append(quad)
	polygon.vertices = points
	for quad: PackedInt32Array in polygons:
		polygon.add_polygon(quad)
	return polygon

func wall_cells(point: Vector2, direction: Vector2, length: float) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	var perpendicular: Vector2 = direction.normalized().orthogonal() if direction.length_squared() > 0.01 else Vector2.UP
	for step: int in range(0, int(length / 20.0) + 1):
		var cell: Vector2i = Vector2i((point + perpendicular * (step * 20.0 - length * 0.5)) / Iso.CELL)
		if not is_blocked(cell) and cell not in result:
			result.append(cell)
	return result

func add_wall(id: int, wall_tiles: Array[Vector2i]) -> void:
	walls[id] = wall_tiles.duplicate()
	for cell: Vector2i in wall_tiles:
		dynamic_counts[cell] = int(dynamic_counts.get(cell, 0)) + 1
	region.navigation_polygon = _ground_polygon()
	_make_wall_bodies.call_deferred(id)

func _make_wall_bodies(id: int) -> void:
	if not walls.has(id):
		return
	var parent: Node2D = Node2D.new()
	parent.name = "IceWall_%d" % id
	simulation_parent.add_child(parent)
	wall_bodies[id] = parent
	for cell: Vector2i in walls[id]:
		var body: StaticBody2D = StaticBody2D.new()
		body.collision_layer = 4
		body.collision_mask = 2
		body.position = (Vector2(cell) + Vector2.ONE * 0.5) * Iso.CELL
		parent.add_child(body)
		var collider: CollisionShape2D = CollisionShape2D.new()
		var shape: RectangleShape2D = RectangleShape2D.new()
		shape.size = Vector2.ONE * Iso.CELL
		collider.shape = shape
		body.add_child(collider)

func remove_wall(id: int) -> void:
	if not walls.has(id):
		return
	for cell: Vector2i in walls[id]:
		dynamic_counts[cell] = int(dynamic_counts[cell]) - 1
		if int(dynamic_counts[cell]) <= 0:
			dynamic_counts.erase(cell)
	walls.erase(id)
	if wall_bodies.has(id):
		var node: Node = wall_bodies[id]
		if is_instance_valid(node):
			node.queue_free()
		wall_bodies.erase(id)
	region.navigation_polygon = _ground_polygon()

func _exit_tree() -> void:
	if air_map.is_valid():
		NavigationServer2D.free_rid(air_map)

func _battle_tile_atlas() -> ImageTexture:
	var source: Image = _tile_texture().get_image()
	var image: Image = Image.create(320,40,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for variant: int in 4:
		for x: int in 80:
			for y: int in 40:
				var color: Color = source.get_pixel(x,y)
				if color.a==0.0: continue
				if variant==1: color = color.darkened(0.10)
				elif variant==2: color = color.lightened(0.06)
				elif variant==3: color = color.lerp(Color(0.44,0.34,0.23),0.65 if terrain!=2 else 0.40)
				image.set_pixel(x+variant*80,y,color)
	return ImageTexture.create_from_image(image)

func _tile_texture() -> ImageTexture:
	var image: Image = Image.create(80, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	var source: Image
	var path: String = ["res://art/terrain/grass.png", "res://art/terrain/stone.png", "res://art/terrain/cave.png"][terrain]
	if ResourceLoader.exists(path):
		var imported: Texture2D = load(path) as Texture2D
		source = imported.get_image()
	if ground_texture != null: source = ground_texture.get_image()
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = map_seed + terrain
	var base: Color = [Color(0.28, 0.34, 0.20), Color(0.33, 0.28, 0.21), Color(0.17, 0.22, 0.24)][terrain]
	for x: int in 80:
		for y: int in 40:
			if absf((x - 39.5) / 40.0) + absf((y - 19.5) / 20.0) <= 1.0:
				var color: Color = base.lightened(rng.randf_range(-0.06, 0.07))
				if source != null:
					var u: float = (float(x) / 80.0 + float(y) / 40.0) * 0.5
					var v: float = (float(y) / 40.0 - float(x) / 80.0) * 0.5 + 0.5
					color = source.get_pixel(clampi(int(u * source.get_width()), 0, source.get_width() - 1), clampi(int(v * source.get_height()), 0, source.get_height() - 1))
				image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)

func _draw() -> void:
	if authored_battlefield: return
	if exploration_definition != null:
		# Native painted terrain is authoritative; do not overlay stale roads/water.
		if not exploration_definition.native_tile_layers.is_empty(): return
		for blocker: PolygonDomain in exploration_definition.blockers:
			if blocker.visual_kind == "water" or blocker.bounds().size.x > blocker.bounds().size.y * 3:
				var polygon: PackedVector2Array = PackedVector2Array()
				for point: Vector2 in blocker.outer:
					polygon.append(Iso.project(point))
				draw_colored_polygon(polygon,Color(0.09,0.25,0.31))
				for point: Vector2 in polygon:
					draw_line(point,point+Vector2(40,0),Color(0.37,0.55,0.52,0.6),2)
		for road: PackedVector2Array in exploration_definition.roads:
			var points: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in road:
				points.append(Iso.project(point))
			draw_polyline(points,Color(0.42,0.34,0.22,0.65),52,true)
			draw_polyline(points,Color(0.56,0.46,0.30,0.45),24,true)
		if exploration_definition.map_id == "river_bay":
			for x: int in range(3250,4100,60):
				for y: int in range(2800,3300,100):
					var at: Vector2 = Iso.project(Vector2(x,y))
					draw_line(at,at+Vector2(45,23),Color(0.3,0.23,0.12,0.75),5)
					draw_line(at+Vector2(5,-2),at+Vector2(7,-12),Color(0.49,0.57,0.22),3)
		return
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 375 + terrain
	# Thin winding paths and sparse details give the diamond floor a traveled scale.
	for i: int in 27:
		var point: Vector2 = Iso.project(Vector2(i * 43 + 70, 170 + sin(i * 0.32) * 65))
		draw_set_transform(point, 0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 33.0, Color(0.56, 0.43, 0.25, 0.20) if terrain != 2 else Color(0.30, 0.37, 0.43, 0.18))
	draw_set_transform(Vector2.ZERO)
	for i: int in 250:
		var at: Vector2 = Vector2(rng.randf_range(25, cells.x * Iso.CELL - 25), rng.randf_range(25, cells.y * Iso.CELL - 25))
		if is_blocked(Vector2i(at / Iso.CELL)):
			continue
		var p: Vector2 = Iso.project(at)
		draw_line(p, p + Vector2(-2, -4), Color(0.55, 0.54, 0.36, 0.24), 1.0)

class GroundProps extends Node2D:
	var map: GroundMap
	func _ready() -> void:
		var path: String = "res://features/world/data/scenery/river_biomes/forest_canopy_mass_0.7.tres" if map.terrain==0 else "res://features/world/data/scenery/river_biomes/granite_valley_granite_mass_0.8.tres" if map.terrain==1 else "res://features/world/data/scenery/river_biomes/deadwood_wastes_rock_deadwood_mass.tres"
		if map.battle_id=="millennium_lake": path = "res://features/world/data/scenery/lake_cliff_left.tres"
		elif map.battle_id=="shaolin_temple": path = "res://features/world/data/scenery/shaolin_incense.tres"
		var source: WorldSceneryDefinition = load(path) as WorldSceneryDefinition
		var wall_x: WorldSceneryDefinition = preload("res://features/world/data/scenery/shaolin_wall_x.tres")
		var wall_y: WorldSceneryDefinition = preload("res://features/world/data/scenery/shaolin_wall_y.tres")
		for p: Vector2 in map.prop_positions:
			var logical: Vector2 = Iso.unproject(p)
			var artwork: WorldSceneryDefinition = source
			if map.battle_id=="shaolin_temple":
				if logical.y<Iso.CELL or logical.y>float(map.cells.y-1)*Iso.CELL: artwork = wall_x
				elif logical.x<Iso.CELL or logical.x>float(map.cells.x-1)*Iso.CELL: artwork = wall_y
			var prop: WorldSceneryView = WorldSceneryView.new()
			prop.position = p
			prop.z_index = 0
			add_child(prop)
			prop.initialize(artwork,logical)

class MapProp extends Node2D:
	var theme: int = 0
	var variant: int = 0
	var atlas_index: int = -1
	var size_multiplier: float = 0.30
	var painted: bool = false
	func _ready() -> void:
		var path: String = "res://art/terrain/props.png"
		if not ResourceLoader.exists(path):
			return
		var texture: Texture2D = load(path) as Texture2D
		var index: int = atlas_index if atlas_index >= 0 else 0 if theme == 0 else 3 if theme == 1 else 4
		var cell: Vector2 = Vector2(texture.get_width() / 3.0, texture.get_height() / 2.0)
		var atlas: AtlasTexture = AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2(Vector2(index % 3, index / 3) * cell, cell)
		var sprite: Sprite2D = Sprite2D.new()
		sprite.texture = atlas
		sprite.scale = Vector2.ONE * size_multiplier
		sprite.position.y = -cell.y * 0.4 * size_multiplier
		add_child(sprite)
		painted = true
	func _draw() -> void:
		draw_set_transform(Vector2.ZERO, 0, Vector2(1, 0.45))
		draw_circle(Vector2.ZERO, 33, Color(0.01, 0.01, 0.01, 0.30))
		draw_set_transform(Vector2.ZERO)
		if painted:
			return
		if theme == 0:
			draw_style_box(_wood(), Rect2(-5, -100, 10, 100))
			for i: int in 5:
				var center: Vector2 = Vector2((i % 2 - 0.5) * 28, -75 - i * 10)
				draw_circle(center, 26 - i, Color(0.11 + i * 0.01, 0.22 + i * 0.01, 0.10))
				draw_arc(center + Vector2(-4, -4), 21 - i, PI, TAU, 12, Color(0.3, 0.36, 0.18, 0.5), 4)
		else:
			var outline: PackedVector2Array = PackedVector2Array([Vector2(-30, -4), Vector2(-28, -75), Vector2(-15, -115), Vector2(13, -105), Vector2(31, -48), Vector2(25, 6)])
			draw_colored_polygon(outline, Color(0.25, 0.25, 0.23) if theme == 1 else Color(0.11, 0.15, 0.19))
			draw_line(Vector2(-15, -105), Vector2(-6, -18), Color(0.45, 0.42, 0.32, 0.5), 4)
			draw_line(Vector2(13, -100), Vector2(23, -12), Color(0.04, 0.05, 0.07), 3)
			if theme == 2:
				draw_line(Vector2(-5, -63), Vector2(6, -38), Color(0.22, 0.55, 0.72, 0.75), 3)
	func _wood() -> StyleBoxFlat:
		var style: StyleBoxFlat = StyleBoxFlat.new()
		style.bg_color = Color(0.23, 0.15, 0.09)
		style.border_color = Color(0.37, 0.26, 0.13)
		style.set_border_width_all(2)
		return style
