extends "res://tools/build_millennium_lake.gd"
## Reuses one-shot native TileSet/author helpers, never lake content or runtime painting.
const TEMPLE_ART: String = "res://art/terrain/shaolin_temple/"
const TEMPLE_ID: String = "shaolin_temple"
const OUTER: Rect2 = Rect2(192,192,1664,1152)
const INNER: Rect2 = Rect2(256,256,1536,1024)
const BUILDINGS: Array[Rect2] = [Rect2(640,288,384,192),Rect2(1408,352,192,128),Rect2(544,1024,192,96),Rect2(1536,704,128,128),Rect2(352,544,128,128)]

func make_atlas() -> void:
	var source: Image = Image.load_from_file(TEMPLE_ART+"materials-v1.png")
	var half: Vector2i = source.get_size()/2
	var samples: Array[Image] = []
	for quadrant: Vector2i in [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(0,0)]: samples.append(source.get_region(Rect2i(quadrant*half,half)))
	samples[0].save_png(TEMPLE_ART+"battle-paving-v1.png")
	var output: Image = Image.create(320,512,false,Image.FORMAT_RGBA8)
	output.fill(Color.TRANSPARENT)
	for kind: int in 5:
		for variant: int in 16:
			for y: int in 32:
				for x: int in 64:
					var delta: Vector2 = Vector2(x-31.5,y-15.5)
					if absf(delta.x)+2*absf(delta.y)>32: continue
					var logical: Vector2 = Iso.unproject(delta)+Vector2(16,16)+Vector2(variant%4,variant/4)*32
					var pixel: Vector2i = Vector2i(logical/128*Vector2(half))
					output.set_pixel(kind*64+x,variant*32+y,samples[kind].get_pixel(posmod(pixel.x,half.x),posmod(pixel.y,half.y)))
	output.save_png(TEMPLE_ART+"tiles-v1.png")

func configure(data: TileData, kind: int, marker: bool) -> void:
	super.configure(data,kind,marker)
	if not marker and kind in [2,4]: data.set_custom_data("visual_kind","building")

func temple_prop(id: String, title: String, rect: Rect2, foot: Vector2, scale_value: float) -> WorldSceneryDefinition:
	var value: WorldSceneryDefinition = WorldSceneryDefinition.new()
	value.display_name = title
	value.texture = props
	value.atlas_region = rect
	value.foot_anchor = foot
	value.sprite_scale = scale_value
	save_resource(value,DATA+"scenery/shaolin_"+id+".tres")
	return value

static func blocked_at(point: Vector2) -> bool:
	if not INNER.has_point(point): return true
	# Two internal dividers, with authored doorways rather than invisible shortcuts.
	if Rect2(256,768,928,64).has_point(point) and not Rect2(736,768,192,64).has_point(point): return true
	if Rect2(1184,256,64,1024).has_point(point) and not Rect2(1184,832,64,192).has_point(point): return true
	for footprint: Rect2 in BUILDINGS:
		if footprint.has_point(point): return true
	return false

func add_prop(id: String, point: Vector2, definition: WorldSceneryDefinition) -> void:
	author(root_map,WorldAuthorNode.Kind.SCENERY,id,point,definition.display_name).sprite_definition = definition

func run() -> void:
	if "--prepare" in OS.get_cmdline_user_args():
		make_atlas()
		quit()
		return
	if FileAccess.file_exists(DATA+TEMPLE_ID+".tscn"):
		print("PRESERVED existing temple. Edit its native scene.")
		quit()
		return
	assert(ResourceLoader.exists(TEMPLE_ART+"tiles-v1.png"),"Prepare and import the PNGs first")
	props = load(TEMPLE_ART+"props-v1.png") as Texture2D
	terrain_set = tile_set(TEMPLE_ART+"tiles-v1.png")
	mask_set = tile_set(TEMPLE_ART+"tiles-v1.png",true)
	for set: TileSet in [terrain_set,mask_set]:
		set.set_terrain_name(0,0,"寺院青磚")
		set.set_terrain_name(0,1,"庭院苔石")
	save_resource(terrain_set,DATA+"tiles/shaolin_temple_terrain.tres")
	save_resource(mask_set,DATA+"tiles/shaolin_temple_masks.tres")
	var layout: SpriteSheetLayout = SpriteSheetLayout.new()
	var monk_texture: Texture2D = load("res://features/units/art/shaolin_guardian-v1.png") as Texture2D
	layout.source_size = Vector2i(monk_texture.get_size())
	var cell: Vector2i = layout.source_size/Vector2i(6,8)
	layout.frame_size = Vector2i(256,256)
	layout.foot_point = Vector2(128,224)
	for row: int in 8:
		for column: int in 6:
			var rect: Rect2i = Rect2i(Vector2i(column,row)*cell,cell)
			# Full staff silhouettes exceed a uniform cell, like the existing authored rigs.
			if column==3:
				rect.position.x -= 24
				rect.size.x = 256
			elif column==4:
				rect.position.x = 758
				rect.size.x = 148
			layout.frame_rects.append(rect)
			layout.source_pivots.append(Vector2(column*cell.x+cell.x*0.5,row*cell.y+cell.y*0.91)-Vector2(rect.position))
	layout.direction_rows[3] = 1
	layout.mirrored_directions[3] = true
	layout.direction_rows[7] = 5
	layout.mirrored_directions[7] = true
	save_resource(layout,"res://features/units/data/layouts/shaolin_guardian_layout.tres")
	var guardian: UnitDefinition = UnitDefinition.new()
	guardian.id = &"shaolin_guardian"
	guardian.display_name = "銅棍護院"
	guardian.role = 9
	guardian.max_health = 260
	guardian.max_mana = 0
	guardian.damage = 16
	guardian.attack_range = 64
	guardian.attack_interval = 1.25
	guardian.speed = 95
	guardian.experience_reward = 75
	guardian.sprite_path = "res://features/units/art/shaolin_guardian-v1.png"
	guardian.sprite_layout = layout
	save_resource(guardian,"res://features/units/data/monsters/shaolin_guardian.tres")
	var arena: ArenaDefinition = ArenaDefinition.new()
	arena.arena_id = TEMPLE_ID
	arena.encounter = EncounterDefinition.new()
	arena.encounter.id = &"shaolin_temple"
	arena.encounter.display_name = "少林寺 · 護院試煉"
	arena.encounter.terrain = 1
	arena.encounter.ground_texture = load(TEMPLE_ART+"battle-paving-v1.png") as Texture2D
	save_resource(arena,DATA+"shaolin_temple_arena.tres")
	root_map = WorldMap2D.new()
	root_map.name = TEMPLE_ID
	root_map.native_tiles_enabled = true
	root_map.show_atlas_reference = false
	root_map.definition = WorldMapDefinition.new()
	root_map.definition.map_id = TEMPLE_ID
	root_map.definition.display_name = "少林寺 · 禪武院"
	root_map.definition.kind = WorldMapDefinition.Kind.DUNGEON
	root_map.definition.extent = Vector2(2048,1536)
	root_map.definition.terrain = 1
	root_map.definition.scene_path = DATA+TEMPLE_ID+".tscn"
	# Nonuniform regions contain complete authored architecture silhouettes.
	var gate: WorldSceneryDefinition = temple_prop("gate","少林寺山門",Rect2(0,0,500,520),Vector2(260,486),0.64)
	gate.description = "少林寺 · 禪武院\n朱牆環繞，經山門入寺；演武院內有一名銅棍護院。"
	save_resource(gate,gate.resource_path)
	var exit_gate: WorldSceneryDefinition = gate.duplicate(true) as WorldSceneryDefinition
	exit_gate.foot_anchor = Vector2(360,436)
	exit_gate.description = "離開少林寺，返回青嶺河灣。"
	save_resource(exit_gate,DATA+"scenery/shaolin_exit_gate.tres")
	var hall: WorldSceneryDefinition = temple_prop("hall","大雄殿",Rect2(490,0,612,550),Vector2(310,520),0.98)
	var wall_x: WorldSceneryDefinition = temple_prop("wall_x","朱牆 · 東西段",Rect2(1100,120,436,390),Vector2(218,294),0.42)
	var wall_y: WorldSceneryDefinition = temple_prop("wall_y","朱牆 · 南北段",Rect2(0,535,512,489),Vector2(256,275),0.42)
	var pavilion: WorldSceneryDefinition = temple_prop("pavilion","演武亭",Rect2(512,550,512,474),Vector2(256,387),0.62)
	var incense: WorldSceneryDefinition = temple_prop("incense","古松碑林與香爐",Rect2(1024,512,512,512),Vector2(256,425),0.48)
	var floor: WorldTileLayer = layer("Ground_TileMap",WorldTileLayer.Role.GROUND)
	var obstacles: WorldTileLayer = layer("Obstacles_TileMap",WorldTileLayer.Role.OBSTACLES)
	var walk: WorldTileLayer = layer("Walkable_Mask",WorldTileLayer.Role.WALKABLE)
	var safe: WorldTileLayer = layer("SafeArea_Mask",WorldTileLayer.Role.SAFE)
	for y: int in 48:
		for x: int in 64:
			var coordinate: Vector2i = Vector2i(x,y)
			var point: Vector2 = (Vector2(coordinate)+Vector2.ONE*0.5)*32
			if not Rect2(160,160,1728,1216).has_point(point): continue
			paint(floor,coordinate,3 if point.x>1248 and point.y>512 else 1 if point.x>1248 else 0)
			if blocked_at(point): paint(obstacles,coordinate,4)
			else: paint(walk,coordinate)
	paint_rect(safe,Rect2(800,1056,288,160))
	author(root_map,WorldAuthorNode.Kind.ARRIVAL,"entrance",Vector2(960,1120)).facing = Vector2.UP
	var exit: WorldAuthorNode = author(root_map,WorldAuthorNode.Kind.PORTAL,"shaolin_exit",Vector2(1024,1248),"返回青嶺河灣")
	exit.target_map_id = "river_bay"
	exit.target_entry_id = "shaolin_return"
	exit.sprite_definition = exit_gate
	# Exterior wall ring. Gate masks are still closed to the outside; only portal changes map.
	for x: int in range(288,1792,160):
		add_prop("outer_north_%d" % x,Vector2(x,224),wall_x)
		if x<928 or x>1120: add_prop("outer_south_%d" % x,Vector2(x,1312),wall_x)
	for y: int in range(288,1281,160):
		add_prop("outer_west_%d" % y,Vector2(224,y),wall_y)
		add_prop("outer_east_%d" % y,Vector2(1824,y),wall_y)
	add_prop("gate_left_wall",Vector2(896,1312),wall_x)
	add_prop("gate_right_wall",Vector2(1152,1312),wall_x)
	# Same native divider geometry as the visual wall segments and their open passages.
	for x: int in [336,496,656,1008,1120]: add_prop("inner_wall_%d" % x,Vector2(x,800),wall_x)
	for y: int in [336,496,656,1136,1232]: add_prop("side_wall_%d" % y,Vector2(1216,y),wall_y)
	add_prop("inner_gate",Vector2(832,800),gate)
	add_prop("main_hall",Vector2(832,480),hall)
	add_prop("north_pavilion",Vector2(1504,480),pavilion)
	add_prop("south_pavilion",Vector2(640,1120),pavilion)
	add_prop("east_incense",Vector2(1600,800),incense)
	add_prop("west_incense",Vector2(416,640),incense)
	var landmark: WorldAuthorNode = author(root_map,WorldAuthorNode.Kind.LANDMARK,"main_courtyard",Vector2(832,640),"大雄殿前院")
	landmark.landmark_kind = "temple"
	var habitat: WorldHabitat = WorldHabitat.new()
	habitat.habitat_id = "bronze_guardian"
	habitat.display_name = "銅棍護院"
	habitat.profile = SpawnProfile.new()
	habitat.profile.target_party_count = 1
	habitat.profile.speed = 55
	habitat.profile.rules.active = false
	habitat.profile.arena_pool = PackedStringArray([TEMPLE_ID])
	var template: PartyTemplate = PartyTemplate.new()
	template.template_id = "shaolin_guardian_solo"
	template.display_name = "銅棍護院"
	template.representative = guardian
	var member: MemberRule = MemberRule.new()
	member.definition = guardian
	member.min_count = 1
	member.max_count = 1
	member.min_level = 8
	member.max_level = 8
	template.members = [member]
	habitat.profile.templates = [template]
	for field: String in ["spawn_domain","activity_domain","chase_domain"]: habitat.set(field,PolygonDomain.rectangle(Rect2(1312,864,160,128)))
	var config: WorldAuthorNode = author(root_map,WorldAuthorNode.Kind.HABITAT,habitat.habitat_id,Vector2.ZERO,habitat.display_name)
	config.habitat = habitat
	config.hide()
	for role: WorldTileLayer.Role in [WorldTileLayer.Role.SPAWN,WorldTileLayer.Role.ACTIVITY,WorldTileLayer.Role.CHASE]:
		paint_rect(layer(["Spawn_","Activity_","Chase_"][role-WorldTileLayer.Role.SPAWN]+habitat.habitat_id,role,habitat.habitat_id),Rect2(1312,864,160,128))
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(root_map)==OK)
	save_resource(packed,DATA+TEMPLE_ID+".tscn")
	root_map.free()
	var exterior: WorldMap2D = (load(DATA+"river_bay.tscn") as PackedScene).instantiate() as WorldMap2D
	var door: WorldAuthorNode = author(exterior,WorldAuthorNode.Kind.PORTAL,"shaolin_door",Vector2(5184,2464),"少林寺入口")
	door.target_map_id = TEMPLE_ID
	door.target_entry_id = "entrance"
	door.sprite_definition = gate
	author(exterior,WorldAuthorNode.Kind.ARRIVAL,"shaolin_return",Vector2(5152,2336))
	author(exterior,WorldAuthorNode.Kind.LANDMARK,"shaolin_landmark",Vector2(5184,2464),"少林寺").landmark_kind = "temple"
	assert(packed.pack(exterior)==OK)
	save_resource(packed,DATA+"river_bay.tscn")
	exterior.free()
	print("SHAOLIN_AUTHORED enclosed native walls, inner gates, building footprints, solo Lv8 guardian")
	quit()
