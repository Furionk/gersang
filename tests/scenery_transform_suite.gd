extends Node
var passed: int = 0
var failed: int = 0
func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1
func _ready() -> void:
	WorldCatalog.initialize()
	var path: String = "res://features/world/data/millennium_lake.tscn"
	var original_hash: String = FileAccess.get_sha256(path)
	var source: WorldMap2D = load(path).instantiate()
	var shrine: WorldAuthorNode = source.find_child("sunken_shrine",true,false)
	var before: WorldMapDefinition = source.compile_definition()
	var geometry: PackedByteArray = nav_geometry(before)
	check(shrine.scale.is_equal_approx(Vector2(1.575,1.575)),"artist shrine scale retained")
	check(WorldAuthoringSnapshot.compile(source).errors.is_empty(),"saved artist map validates")
	var original_basis: Transform2D = shrine.sprite_definition.sprite_basis
	for authored_transform: Transform2D in [shrine.transform,Transform2D(0.25,Vector2(1.8,0.7),0,shrine.position),Transform2D(0,Vector2(-1.2,1.1),0,shrine.position)]:
		shrine.transform=authored_transform
		var compiled: WorldMapDefinition = source.compile_definition()
		check(WorldAuthoringSnapshot.compile(source).errors.is_empty(),"native visual scale/rotation/mirror permitted")
		check(nav_geometry(compiled)==geometry,"visual transform preserves navigation exactly")
		var visual: Node2D = Node2D.new()
		add_child(visual)
		var ground: GroundMap = GroundMap.new()
		ground._build_exploration_props(visual,compiled)
		var view: WorldSceneryView
		for candidate: WorldSceneryView in ground.scenery_views:
			if candidate.name=="Scenery_sunken_shrine": view=candidate
		var basis: Transform2D = authored_transform
		basis.origin=Vector2.ZERO
		check(view!=null and view.sprite.transform.is_equal_approx(basis*shrine.sprite_definition.artwork_transform()),"runtime sprite matches editor parent transform")
		check(view!=null and view.position.is_equal_approx(Iso.project(WorldAuthorTree.logical_position(shrine,source))),"foot position stays authored")
		visual.free()
		ground.free()
	check(shrine.sprite_definition.sprite_basis==original_basis,"shared art resource untouched")
	shrine.scale=Vector2.ZERO
	check(not WorldAuthoringSnapshot.compile(source).errors.is_empty(),"zero scale remains invalid")
	source.free()
	check(FileAccess.get_sha256(path)==original_hash,"formal artist scene not resaved")
	print("SCENERY_TRANSFORM_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)
func nav_geometry(map: WorldMapDefinition) -> PackedByteArray:
	var values: Array = []
	for domains: Array[PolygonDomain] in [map.walkable,map.blockers]:
		var shapes: Array = []
		for domain: PolygonDomain in domains: shapes.append([domain.outer,domain.holes])
		values.append(shapes)
	return var_to_bytes(values)
