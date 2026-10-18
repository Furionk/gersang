extends "res://tools/expand_rainbow_dungeon.gd"
## One-time authored scenery pass, with physical masks preserved except pillar footprints.
func run() -> void:
	var world: WorldMap2D = load(WORLD).instantiate()
	if world.has_meta("rainbow_dressed_v1"): world.free(); push_error("Already dressed; refusing overwrite"); quit(1); return
	var ground: WorldTileLayer = world.get_node("Ground/Ground_TileMap")
	var walls: WorldTileLayer = world.get_node("Ground/Obstacles_TileMap")
	walls.tile_set = ground.tile_set
	for cell: Vector2i in walls.get_used_cells():
		walls.set_cell(cell,0,Vector2i(8+posmod(cell.x,8),1+posmod(cell.y,8)))
	var scenery: Node = world.get_node("Scenery")
	prop(scenery,"PriestAltar",0,Vector2(2950,420),0.85,true)
	prop(scenery,"DragonSigil",1,Vector2(4370,570),1.2,true)
	# Border props sit in lava or outside the walkable platform; no invisible traversal obstacles.
	for p: Vector2 in [Vector2(1216,480),Vector2(1216,740),Vector2(2464,480),Vector2(2464,740),Vector2(3584,480),Vector2(3584,740)]:
		prop(scenery,"Brazier%d" % scenery.get_child_count(),2,p,0.21,false)
	prop(scenery,"DragonGate",3,Vector2(4380,96),0.7,false)
	world.set_meta("rainbow_dressed_v1",true); pack(world,WORLD); world.free()
	for id: String in ["rainbow_temple","rainbow_forge","rainbow_sanctum","rainbow_throne"]:
		var map: BattlefieldMap = load("res://features/battle/maps/%s.tscn" % id).instantiate()
		map.get_node("Ground").z_index = -3500
		var props: Node = map.get_node_or_null("Scenery")
		if props == null: props = Node2D.new(); props.name = "Scenery"; map.add_child(props)
		if id != "rainbow_temple":
			prop(props,"RitualFloor",1 if id == "rainbow_throne" else 0,Vector2(800,600),1.2 if id == "rainbow_throne" else 0.85,true)
			for p: Vector2 in [Vector2(180,80),Vector2(1400,80),Vector2(80,1240),Vector2(1520,1240)]:
				prop(props,"Brazier%d" % props.get_child_count(),2,p,0.28,false)
			if id == "rainbow_throne": prop(props,"DragonMonument",3,Vector2(800,70),0.75,false)
		map.set_meta("rainbow_dressed_v1",true)
		pack(map,"res://features/battle/maps/%s.tscn" % id); map.free()
	print("RAINBOW_DRESSED native altars and boundary props; ground below telegraphs")
	quit()

func prop(parent: Node, id: String, index: int, at: Vector2, size: float, floor_prop: bool) -> void:
	var sprite := Sprite2D.new(); sprite.name = id
	var atlas := AtlasTexture.new(); atlas.atlas = load("res://features/rainbow/art/temple-props-v1.png")
	atlas.region = [Rect2(0,0,627,510),Rect2(627,0,627,510),Rect2(0,520,610,734),Rect2(610,520,644,734)][index]
	sprite.texture = atlas; sprite.position = Iso.project(at); sprite.scale = Vector2.ONE * size
	if not floor_prop: sprite.offset.y = -atlas.region.size.y * 0.46
	sprite.set_meta("world_scenery_id",id); sprite.set_meta("world_scenery_name",["祭火法陣","龍心王座","神殿火盆","龍骨門"][index])
	sprite.set_meta("scenery_sort_override",0 if floor_prop else 1)
	parent.add_child(sprite)
