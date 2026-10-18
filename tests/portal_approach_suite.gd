extends Node
var passed: int = 0
var failed: int = 0
func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ",label)
	if ok: passed+=1
	else: failed+=1
func _ready() -> void:
	var map: WorldMapDefinition = WorldMapDefinition.new()
	map.map_id="portal_fixture"
	map.extent=Vector2(512,512)
	map.walkable=[PolygonDomain.rectangle(Rect2(0,0,512,512))]
	map.blockers=[PolygonDomain.rectangle(Rect2(260,180,100,150))]
	var nav: WorldNavigationService = WorldNavigationService.new()
	nav.register_map(map)
	var start: Vector2 = Vector2(100,256)
	for offset: float in [0.0,4.0,8.0,12.0]:
		var center: Vector2 = Vector2(270+offset,256)
		check(not nav.find_path(map.map_id,"","PLAYER",start,center,16).ok,"blocked center reproduces original failure")
		var route: Dictionary = nav.find_portal_approach(map.map_id,start,center,65,16)
		check(route.ok,"dragged portal keeps reachable trigger area")
		if route.ok:
			check(route.points[-1].distance_to(center)<65,"endpoint triggers entrance")
			for i: int in range(1,route.points.size()):
				check(nav.segment_legal(map.map_id,"","PLAYER",route.points[i-1],route.points[i],16),"approach never crosses blocker")
	var no_space: Dictionary = nav.find_portal_approach(map.map_id,start,Vector2(310,250),20,16)
	check(not no_space.ok and no_space.reason=="PORTAL_NO_REACHABLE_APPROACH","fully blocked trigger refuses without teleport")
	var inside: Dictionary = nav.find_portal_approach(map.map_id,Vector2(220,256),Vector2(270,256),65,16)
	check(inside.ok and inside.points.size()==1,"already within trigger requires no center walk")
	WorldCatalog.initialize()
	var authored: WorldMap2D = load("res://features/world/data/shaolin_temple.tscn").instantiate()
	var before: WorldMapDefinition = authored.compile_definition()
	var geometry: PackedByteArray = navigation_geometry(before)
	var moved_scenery: bool = false
	for node: Node in WorldAuthorTree.nodes(authored):
		if NativeScenery.is_author(node) or (node is WorldAuthorNode and node.kind==WorldAuthorNode.Kind.SCENERY):
			node.position+=Vector2(75,-31)
			moved_scenery=true
			break
	check(moved_scenery and navigation_geometry(authored.compile_definition())==geometry,"building parent drag cannot change navigation masks")
	var exit_node: WorldAuthorNode = authored.find_child("shaolin_exit",true,false)
	exit_node.position+=Vector2(12,6)
	var after: WorldMapDefinition = authored.compile_definition()
	check(navigation_geometry(after)==geometry,"portal parent drag cannot change navigation masks")
	check(before.portals!=after.portals,"portal parent drag updates interaction position")
	authored.free()
	var temple: WorldMapDefinition = WorldCatalog.definitions.shaolin_temple
	nav.register_map(temple)
	var portal: Dictionary = {}
	for item: Dictionary in temple.portals:
		if item.id=="shaolin_exit": portal=item
	check(not portal.is_empty(),"actual shaolin_exit retained")
	if not portal.is_empty():
		var from: Vector2 = temple.entries.values()[0].point
		var route: Dictionary = nav.find_portal_approach(temple.map_id,from,portal.point,portal.radius,16)
		check(route.ok,"current saved Shaolin exit reachable from arrival")
		if route.ok: check(route.points[-1].distance_to(portal.point)<float(portal.radius),"real entrance route ends within trigger")
	print("PORTAL_APPROACH_RESULT passed=",passed," failed=",failed)
	get_tree().quit(0 if failed==0 else 1)

func navigation_geometry(map: WorldMapDefinition) -> PackedByteArray:
	var values: Array = []
	for domains: Array[PolygonDomain] in [map.walkable,map.blockers]:
		var shapes: Array = []
		for domain: PolygonDomain in domains: shapes.append([domain.outer,domain.holes])
		values.append(shapes)
	return var_to_bytes(values)
