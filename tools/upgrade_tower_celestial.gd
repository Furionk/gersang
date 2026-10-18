extends SceneTree
## One-shot, scoped art upgrade. Never rerun over a reviewed celestial tower.
const ART: String = "res://art/terrain/shenchao_tower/"
func _initialize() -> void: call_deferred("run")
func save(data: Resource, path: String) -> void:
	assert(ResourceSaver.save(data,path)==OK)
	data.take_over_path(path)
func pack(node: Node, path: String) -> void:
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(node)==OK)
	save(packed,path)
func tiles(texture: Texture2D, size: Vector2i, region: Vector2i, count: int) -> TileSet:
	var result: TileSet = TileSet.new()
	result.tile_shape=TileSet.TILE_SHAPE_ISOMETRIC
	result.tile_layout=TileSet.TILE_LAYOUT_DIAMOND_DOWN
	result.tile_size=size
	result.add_physics_layer()
	result.add_custom_data_layer(); result.set_custom_data_layer_name(0,"blocked"); result.set_custom_data_layer_type(0,TYPE_BOOL)
	result.add_custom_data_layer(); result.set_custom_data_layer_name(1,"visual_kind"); result.set_custom_data_layer_type(1,TYPE_STRING)
	var atlas: TileSetAtlasSource = TileSetAtlasSource.new()
	atlas.texture=texture; atlas.texture_region_size=region
	result.add_source(atlas,0)
	for i: int in count:
		atlas.create_tile(Vector2i(i,0))
		var data: TileData=atlas.get_tile_data(Vector2i(i,0),0)
		data.set_custom_data("blocked",false); data.set_custom_data("visual_kind","ground")
	return result
func sprite(root: Node, parent: Node, label: String, texture: Texture2D, at: Vector2, anchor: Vector2, scale_value: float, ground: bool=false) -> Sprite2D:
	var item: Sprite2D = Sprite2D.new()
	item.name=label; item.texture=texture; item.position=Iso.project(at)
	item.centered=false; item.offset=-anchor; item.scale=Vector2.ONE*scale_value
	item.set_meta("scenery_sort_override",0 if ground else 1)
	item.set_meta("world_scenery_id",label)
	parent.add_child(item); item.owner=root
	return item
func style(texture: Texture2D, anchor: Vector2, scale_value: float, label: String) -> WorldSceneryDefinition:
	var data: WorldSceneryDefinition=WorldSceneryDefinition.new()
	data.texture=texture; data.foot_anchor=anchor; data.sprite_scale=scale_value; data.display_name=label
	return data
func run() -> void:
	var path: String="res://features/world/data/shenchao_tower.tscn"
	var world: WorldMap2D=load(path).instantiate()
	if world.has_meta("celestial_revision"):
		push_error("Reviewed celestial scene exists; refusing overwrite"); world.free(); quit(1); return
	var old: WorldMapDefinition=world.compile_definition()
	var castle: Texture2D=load(ART+"celestial-tower-v1.png")
	var clouds: Texture2D=load(ART+"cloud-sea-v1.png")
	var rail: Texture2D=load(ART+"celestial-balustrade-v1.svg")
	var obelisk: Texture2D=load(ART+"element-obelisk-v1.svg")
	var anchor: Vector2=Vector2(castle.get_width()*0.5,castle.get_height()-16)
	var ground: WorldTileLayer=world.get_node("Ground/Ground_TileMap")
	var walk: WorldTileLayer=world.get_node("Ground/Walkable_Mask")
	var obstacles: WorldTileLayer=world.get_node("Ground/Obstacles_TileMap")
	ground.tile_set=tiles(load(ART+"world-marble-v1.svg"),Vector2i(64,32),Vector2i(64,32),4)
	save(ground.tile_set,ART+"world-marble-v1.tres")
	ground.modulate=Color.WHITE
	for cell: Vector2i in ground.get_used_cells():
		if obstacles.get_cell_source_id(cell)>=0: ground.erase_cell(cell); continue
		var border: bool=cell.x in [2,77,35,44] or cell.y in [2,29,31,57,59,85,87,117]
		var inlay: bool=cell.x in [38,41]
		ground.set_cell(cell,0,Vector2i(2 if border else 3 if inlay else (1 if (cell.x+cell.y)%7==0 else 0),0))
	# Dedicated invisible artwork on obstacles; collision polygons are copied unchanged.
	obstacles.tile_set=obstacles.tile_set.duplicate(true)
	for i: int in obstacles.tile_set.get_source_count():
		var source: TileSetAtlasSource=obstacles.tile_set.get_source(obstacles.tile_set.get_source_id(i)) as TileSetAtlasSource
		if source!=null: source.texture=load(ART+"clear-mask-v1.svg")
	save(obstacles.tile_set,ART+"invisible-obstacles-v1.tres")
	var sky: WorldTileLayer=WorldTileLayer.new()
	sky.name="CelestialCloudSea"; sky.position=Vector2(-32,0)
	sky.tile_set=tiles(clouds,Vector2i(64,32),Vector2i(clouds.get_size()),1)
	save(sky.tile_set,ART+"cloud-sea-v1.tres")
	world.get_node("Ground").add_child(sky); sky.owner=world
	world.get_node("Ground").move_child(sky,0)
	for x: int in range(-4,4):
		for y: int in range(-1,5):
			var point: Vector2=Vector2(x*(clouds.get_width()/64)*64,y*(clouds.get_height()/64)*64)
			sky.set_cell(Vector2i((Iso.unproject(point)/32).round()),0,Vector2i.ZERO)
	var gate: WorldSceneryDefinition=style(castle,anchor,0.5,"神抄天門")
	save(gate,ART+"celestial-gate-v1.tres")
	var marker: WorldSceneryDefinition=style(obelisk,Vector2(160,360),0.6,"元素星碑")
	save(marker,ART+"element-obelisk-v1.tres")
	world.get_node("Entrances/tower_exit").sprite_definition=gate
	var scenery: Node=world.get_node("Scenery")
	for child: Node in scenery.get_children():
		if child is WorldAuthorNode: child.sprite_definition=marker
		if child is Sprite2D:
			child.visible=false # Preserve original authored artwork in the scene.
			var item: Sprite2D=sprite(world,scenery,"CelestialRail_"+str(child.name),rail,Iso.unproject(child.position),Vector2(130,185),0.9)
			item.flip_h=(child.texture as AtlasTexture).region.size.x>450 if child.texture is AtlasTexture else false
	sprite(world,scenery,"CelestialCrown",castle,Vector2(1280,100),anchor,1.1)
	for tier: int in 4:
		for element: int in 4:
			sprite(world,scenery,"ElementSeal_%d_%d"%[tier,element],load(ART+"element-seal-%d-v1.svg"%element),Vector2(400+576*element,3120-896*tier),Vector2(256,128),1.5 if tier==3 else 1.0,true)
	world.set_meta("celestial_revision",1)
	var compiled: WorldMapDefinition=world.compile_definition()
	assert(compiled.walkable.size()==old.walkable.size() and compiled.blockers.size()==old.blockers.size())
	for i: int in old.walkable.size(): assert(compiled.walkable[i].outer==old.walkable[i].outer)
	for i: int in old.blockers.size(): assert(compiled.blockers[i].outer==old.blockers[i].outer)
	assert(walk.tile_map_data==world.get_node("Ground/Walkable_Mask").tile_map_data)
	pack(world,path); world.free()
	path="res://features/battle/maps/shenchao_tower.tscn"
	var battle: BattlefieldMap=load(path).instantiate()
	var before: Dictionary=BattlefieldCompiler.compile(battle)
	var floor: BattleTileLayer=battle.get_node("Terrain/Ground")
	floor.tile_set=tiles(load(ART+"battle-marble-v1.svg"),Vector2i(80,40),Vector2i(80,40),4)
	save(floor.tile_set,ART+"battle-marble-v1.tres")
	for cell: Vector2i in floor.get_used_cells():
		var border: bool=cell.x<2 or cell.y<2 or cell.x>battle.battlefield_cells.x-3 or cell.y>battle.battlefield_cells.y-3
		floor.set_cell(cell,0,Vector2i(2 if border else 3 if cell.x%12==0 else (1 if (cell.x+cell.y)%7==0 else 0),0))
	scenery=battle.get_node("Scenery")
	for child: Node in scenery.get_children():
		if child is Sprite2D:
			child.hide()
			sprite(battle,scenery,"CelestialRail_"+str(child.name),rail,Iso.unproject(child.position),Vector2(130,185),0.48)
	var sky_sprite: Sprite2D=Sprite2D.new()
	sky_sprite.name="CloudSeaBackdrop"; sky_sprite.texture=clouds; sky_sprite.z_index=-4000
	sky_sprite.texture_repeat=CanvasItem.TEXTURE_REPEAT_ENABLED
	sky_sprite.region_enabled=true; sky_sprite.region_rect=Rect2(-4096,-4096,8192,8192)
	battle.add_child(sky_sprite); sky_sprite.owner=battle
	sprite(battle,scenery,"CelestialTower",castle,Vector2(battle.battlefield_cells.x*20,40),anchor,0.7)
	for i: int in 4:
		var at: Vector2=Vector2((0.27 if i%2==0 else 0.73)*battle.battlefield_cells.x*40,(0.28 if i<2 else 0.72)*battle.battlefield_cells.y*40)
		sprite(battle,scenery,"ElementSeal_%d"%i,load(ART+"element-seal-%d-v1.svg"%i),at,Vector2(256,128),0.8,true)
	battle.set_meta("celestial_revision",1)
	var after: Dictionary=BattlefieldCompiler.compile(battle)
	assert(after.errors.is_empty() and before.blocked==after.blocked and before.zones==after.zones)
	pack(battle,path); battle.free()
	print("CELESTIAL_UPGRADE_OK native world/battle navigation preserved")
	quit()
