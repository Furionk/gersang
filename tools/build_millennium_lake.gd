extends SceneTree
## One-shot authoring, never a game boot hook. Existing lake scenes are preserved.
const ART: String = "res://art/terrain/millennium_lake/"
const DATA: String = "res://features/world/data/"
const ID: String = "millennium_lake"
var root_map: WorldMap2D
var props: Texture2D
var terrain_set: TileSet
var mask_set: TileSet

func _initialize() -> void: call_deferred("run")

func save_resource(value: Resource, path: String) -> void:
	assert(ResourceSaver.save(value,path)==OK,"Cannot save "+path)
	value.take_over_path(path)

func tile_set(texture_path: String, marker: bool = false) -> TileSet:
	var set: TileSet = TileSet.new()
	set.tile_size = Vector2i(64,32)
	set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	set.add_physics_layer()
	set.set_physics_layer_collision_layer(0,0)
	for entry: Array in [["blocked",TYPE_BOOL],["visual_kind",TYPE_STRING]]:
		set.add_custom_data_layer()
		var index: int = set.get_custom_data_layers_count()-1
		set.set_custom_data_layer_name(index,entry[0])
		set.set_custom_data_layer_type(index,entry[1])
	set.add_terrain_set()
	set.set_terrain_set_mode(0,TileSet.TERRAIN_MODE_MATCH_SIDES)
	for title: String in ["湖岸苔土","祭壇石路"]:
		set.add_terrain(0)
		set.set_terrain_name(0,set.get_terrains_count(0)-1,title)
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture = load(texture_path) as Texture2D
	atlas.texture_region_size = Vector2i(64,32)
	set.add_source(atlas,0)
	for kind: int in 5:
		for variant: int in 16:
			var cell: Vector2i = Vector2i(kind,variant)
			atlas.create_tile(cell)
			configure(atlas.get_tile_data(cell,0),kind,marker)
			if kind<2:
				var data: TileData = atlas.get_tile_data(cell,0)
				data.terrain_set = 0
				data.terrain = kind
				for bit: int in 16:
					if data.is_valid_terrain_peering_bit(bit): data.set_terrain_peering_bit(bit,kind)
	# All empty/earth/paving neighbor combinations preserve outer edge cells.
	for kind: int in 2:
		for code: int in 81:
			var cell: Vector2i = Vector2i(kind,0)
			var alternate: int = atlas.create_alternative_tile(cell)
			var data: TileData = atlas.get_tile_data(cell,alternate)
			configure(data,kind,marker)
			data.terrain_set = 0
			data.terrain = kind
			var digits: int = code
			for bit: int in 16:
				if data.is_valid_terrain_peering_bit(bit):
					data.set_terrain_peering_bit(bit,digits%3-1)
					digits/=3
	return set

func configure(data: TileData, kind: int, marker: bool) -> void:
	data.set_custom_data("blocked",not marker and kind in [2,4])
	data.set_custom_data("visual_kind","mask" if marker else ["ground","road","water","road","rock"][kind])
	data.set_collision_polygons_count(0,1)
	data.set_collision_polygon_points(0,0,PackedVector2Array([Vector2(0,-16),Vector2(32,0),Vector2(0,16),Vector2(-32,0)]))

func make_atlas() -> void:
	var material: Image = Image.load_from_file(ART+"materials-v1.png")
	var half: Vector2i = material.get_size()/2
	var materials: Array[Image] = []
	for quadrant: Vector2i in [Vector2i(0,0),Vector2i(0,1),Vector2i(1,0),Vector2i(1,1),Vector2i(0,1)]:
		materials.append(material.get_region(Rect2i(quadrant*half,half)))
	materials[0].save_png(ART+"battle-earth-v1.png")
	var image: Image = Image.create(320,512,false,Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	for kind: int in 5:
		for variant: int in 16:
			for y: int in 32:
				for x: int in 64:
					var delta: Vector2 = Vector2(x-31.5,y-15.5)
					if absf(delta.x)+2*absf(delta.y)>32: continue
					var logical: Vector2 = Iso.unproject(delta)+Vector2(16,16)+Vector2(variant%4,variant/4)*32
					var uv: Vector2i = Vector2i(logical/128*Vector2(half))
					var color: Color = materials[kind].get_pixel(posmod(uv.x,half.x),posmod(uv.y,half.y))
					if kind==4: color = color.darkened(0.3)
					image.set_pixel(kind*64+x,variant*32+y,color)
	image.save_png(ART+"tiles-v1.png")

func author(parent: WorldMap2D, kind: WorldAuthorNode.Kind, id: String, point: Vector2, title: String = "") -> WorldAuthorNode:
	var node: WorldAuthorNode = WorldAuthorNode.new()
	node.name = id
	node.kind = kind
	node.stable_id = id
	node.position = point
	node.display_name = title
	parent.add_child(node)
	node.owner = parent
	return node

func scenery(id: String, index: int, scale_value: float, foot: Vector2) -> WorldSceneryDefinition:
	var value: WorldSceneryDefinition = WorldSceneryDefinition.new()
	value.display_name = id
	value.texture = props
	value.atlas_region = Rect2(Vector2(index%3,index/3)*512,Vector2(512,512))
	value.foot_anchor = foot
	value.sprite_scale = scale_value
	save_resource(value,DATA+"scenery/lake_"+id+".tres")
	return value

func layer(title: String, role: WorldTileLayer.Role, region: String = "") -> WorldTileLayer:
	var node: WorldTileLayer = WorldTileLayer.new()
	node.name = title
	node.role = role
	node.region_id = region
	node.tile_set = terrain_set if role<WorldTileLayer.Role.WALKABLE else mask_set
	node.position = Vector2(-32,0)
	node.z_index = -3500 if role==WorldTileLayer.Role.GROUND else -3400 if role==WorldTileLayer.Role.OBSTACLES else 100
	node.visible = role<WorldTileLayer.Role.WALKABLE
	node.collision_enabled = false
	node.navigation_enabled = false
	root_map.add_child(node)
	node.owner = root_map
	return node

func paint(node: WorldTileLayer, cell: Vector2i, kind: int = 0) -> void:
	node.set_cell(cell,0,Vector2i(kind,posmod(cell.x,4)+posmod(cell.y,4)*4))

func paint_rect(node: WorldTileLayer, rect: Rect2) -> void:
	for y: int in range(int(rect.position.y/32),int(rect.end.y/32)):
		for x: int in range(int(rect.position.x/32),int(rect.end.x/32)): paint(node,Vector2i(x,y))

func run() -> void:
	if "--prepare" in OS.get_cmdline_user_args():
		make_atlas()
		quit()
		return
	if FileAccess.file_exists(DATA+ID+".tscn"):
		print("PRESERVED existing lake. Edit native scene directly.")
		quit()
		return
	assert(ResourceLoader.exists(ART+"tiles-v1.png"),"Run -- --prepare and editor import before authoring")
	props = load(ART+"props-v1.png") as Texture2D
	terrain_set = tile_set(ART+"tiles-v1.png")
	mask_set = tile_set(ART+"tiles-v1.png",true)
	save_resource(terrain_set,DATA+"tiles/millennium_lake_terrain.tres")
	save_resource(mask_set,DATA+"tiles/millennium_lake_masks.tres")
	var layout: SpriteSheetLayout = SpriteSheetLayout.new()
	layout.source_size = Vector2i(1086,1448)
	layout.frame_size = Vector2i(224,224)
	layout.foot_point = Vector2(112,202)
	for row: int in 8:
		for column: int in 6:
			layout.frame_rects.append(Rect2i(column*181,row*181,181,181))
			layout.source_pivots.append(Vector2(90.5,167))
	save_resource(layout,"res://features/units/data/layouts/lake_guardian_layout.tres")
	var guardian: UnitDefinition = UnitDefinition.new()
	guardian.id = &"lake_guardian"
	guardian.display_name = "千年湖守"
	guardian.role = 9
	guardian.max_health = 240
	guardian.max_mana = 0
	guardian.damage = 14
	guardian.speed = 88
	guardian.attack_range = 55
	guardian.attack_interval = 1.3
	guardian.experience_reward = 65
	guardian.sprite_path = "res://features/units/art/lake_guardian-v1.png"
	guardian.sprite_layout = layout
	save_resource(guardian,"res://features/units/data/monsters/lake_guardian.tres")
	var arena: ArenaDefinition = ArenaDefinition.new()
	arena.arena_id = "millennium_lake"
	arena.encounter = EncounterDefinition.new()
	arena.encounter.id = &"millennium_lake"
	arena.encounter.display_name = "千年湖 · 湖守試煉"
	arena.encounter.terrain = 2
	arena.encounter.ground_texture = load(ART+"battle-earth-v1.png") as Texture2D
	save_resource(arena,DATA+"millennium_lake_arena.tres")
	root_map = WorldMap2D.new()
	root_map.name = ID
	root_map.native_tiles_enabled = true
	root_map.show_atlas_reference = false
	root_map.definition = WorldMapDefinition.new()
	root_map.definition.map_id = ID
	root_map.definition.display_name = "千年湖 · 沉祠湖境"
	root_map.definition.kind = WorldMapDefinition.Kind.DUNGEON
	root_map.definition.extent = Vector2(2048,1536)
	root_map.definition.terrain = 2
	root_map.definition.scene_path = DATA+ID+".tscn"
	var entrance: WorldSceneryDefinition = scenery("gate",0,0.52,Vector2(256,452))
	entrance.description = "千年湖\n沿木橋通往沉祠，湖岸棲息著一隻千年湖守。"
	save_resource(entrance,entrance.resource_path)
	var cliff_left: WorldSceneryDefinition = scenery("cliff_left",1,0.68,Vector2(256,420))
	var cliff_right: WorldSceneryDefinition = scenery("cliff_right",2,0.68,Vector2(256,420))
	var rocks: WorldSceneryDefinition = scenery("reeds",3,0.26,Vector2(256,428))
	var shrine: WorldSceneryDefinition = scenery("shrine",4,0.6,Vector2(256,456))
	var bridge: WorldSceneryDefinition = scenery("bridge",5,0.55,Vector2(256,326))
	var floor: WorldTileLayer = layer("Ground_TileMap",WorldTileLayer.Role.GROUND)
	var obstacles: WorldTileLayer = layer("Obstacles_TileMap",WorldTileLayer.Role.OBSTACLES)
	var walk: WorldTileLayer = layer("Walkable_Mask",WorldTileLayer.Role.WALKABLE)
	var safe: WorldTileLayer = layer("SafeArea_Mask",WorldTileLayer.Role.SAFE)
	for y: int in 48:
		for x: int in 64:
			var cell: Vector2i = Vector2i(x,y)
			var point: Vector2 = (Vector2(cell)+Vector2.ONE*0.5)*32
			var wet: bool = pow((point.x-1152)/480,2)+pow((point.y-896)/352,2)<1
			var island: bool = Rect2(1024,768,256,256).has_point(point)
			var bridge_cell: bool = Rect2(1120,480,96,576).has_point(point) or Rect2(608,832,1088,96).has_point(point)
			var boundary: bool = x<2 or y<2 or x>=62 or y>=46
			var path: bool = absf(point.x-point.y)<40 and point.x<750
			paint(floor,cell,3 if wet and bridge_cell and not island else 1 if island or path else 0)
			if boundary: paint(obstacles,cell,4)
			elif wet and not island and not bridge_cell: paint(obstacles,cell,2)
			else: paint(walk,cell)
	paint_rect(safe,Rect2(96,96,448,448))
	var arrival: WorldAuthorNode = author(root_map,WorldAuthorNode.Kind.ARRIVAL,"entrance",Vector2(352,352))
	arrival.facing = Vector2.DOWN
	var exit: WorldAuthorNode = author(root_map,WorldAuthorNode.Kind.PORTAL,"lake_exit",Vector2(224,224),"返回青嶺河灣")
	exit.target_map_id = "river_bay"
	exit.target_entry_id = "lake_return"
	exit.sprite_definition = entrance
	var altar: WorldAuthorNode = author(root_map,WorldAuthorNode.Kind.LANDMARK,"sunken_shrine",Vector2(1152,864),"千年沉祠")
	altar.landmark_kind = "shrine"
	altar.sprite_definition = shrine
	for y: int in [560,720]: author(root_map,WorldAuthorNode.Kind.SCENERY,"bridge_%d" % y,Vector2(1168,y),"苔木橋").sprite_definition = bridge
	# Repeated cliff sprites enclose the ground; collision is painted separately.
	for x: int in range(192,2048,240):
		for y: int in [48,1504]: author(root_map,WorldAuthorNode.Kind.SCENERY,"cliff_x_%d_%d" % [x,y],Vector2(x,y),"苔岩壁").sprite_definition = cliff_right
	for y: int in range(192,1536,240):
		for x: int in [48,2016]: author(root_map,WorldAuthorNode.Kind.SCENERY,"cliff_y_%d_%d" % [x,y],Vector2(x,y),"苔岩壁").sprite_definition = cliff_left
	for i: int in 26:
		var angle: float = float(i)/26*TAU
		var point: Vector2 = Vector2(1152,896)+Vector2(cos(angle)*565,sin(angle)*422)
		if absf(point.y-880)<80 or absf(point.x-1168)<80: continue
		author(root_map,WorldAuthorNode.Kind.SCENERY,"reeds_%d" % i,point,"湖岸苔石").sprite_definition = rocks
	var habitat: WorldHabitat = WorldHabitat.new()
	habitat.habitat_id = "lake_guardian"
	habitat.display_name = "千年湖守"
	habitat.profile = SpawnProfile.new()
	habitat.profile.target_party_count = 1
	habitat.profile.speed = 55
	habitat.profile.rules.active = false
	habitat.profile.arena_pool = PackedStringArray([ID])
	var template: PartyTemplate = PartyTemplate.new()
	template.template_id = "lake_guardian_solo"
	template.display_name = "千年湖守"
	template.representative = guardian
	var member: MemberRule = MemberRule.new()
	member.definition = guardian
	member.min_count = 1
	member.max_count = 1
	member.min_level = 6
	member.max_level = 6
	template.members = [member]
	habitat.profile.templates = [template]
	for field: String in ["spawn_domain","activity_domain","chase_domain"]: habitat.set(field,PolygonDomain.rectangle(Rect2(1504,1152,160,128)))
	var config: WorldAuthorNode = author(root_map,WorldAuthorNode.Kind.HABITAT,habitat.habitat_id,Vector2.ZERO,habitat.display_name)
	config.habitat = habitat
	config.visible = false
	for role: WorldTileLayer.Role in [WorldTileLayer.Role.SPAWN,WorldTileLayer.Role.ACTIVITY,WorldTileLayer.Role.CHASE]:
		var mask: WorldTileLayer = layer(["Spawn_","Activity_","Chase_"][role-WorldTileLayer.Role.SPAWN]+habitat.habitat_id,role,habitat.habitat_id)
		paint_rect(mask,Rect2(1504,1152,160,128))
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(root_map)==OK)
	save_resource(packed,DATA+ID+".tscn")
	root_map.free()
	# Add only new author nodes to the exterior; native terrain and old IDs stay intact.
	var exterior: WorldMap2D = (load(DATA+"river_bay.tscn") as PackedScene).instantiate() as WorldMap2D
	var door: WorldAuthorNode = author(exterior,WorldAuthorNode.Kind.PORTAL,"lake_door",Vector2(4608,2464),"千年湖入口")
	door.target_map_id = ID
	door.target_entry_id = "entrance"
	door.sprite_definition = entrance
	author(exterior,WorldAuthorNode.Kind.ARRIVAL,"lake_return",Vector2(4736,2368))
	var mark: WorldAuthorNode = author(exterior,WorldAuthorNode.Kind.LANDMARK,"lake_landmark",Vector2(4608,2464),"千年湖")
	mark.landmark_kind = "well"
	assert(packed.pack(exterior)==OK)
	save_resource(packed,DATA+"river_bay.tscn")
	exterior.free()
	print("LAKE_AUTHORED native layers, two-way entrance, exactly one Lv6 guardian")
	quit()
