extends SceneTree
const PATH: String="res://features/world/data/millennium_lake.tscn"
func geometry_stamp(map: WorldMapDefinition) -> String:
	var data: Array=[]
	for list: Array in [map.walkable,map.blockers,map.safe_areas]:
		var shapes: Array=[]
		for domain: PolygonDomain in list: shapes.append([domain.outer,domain.holes])
		data.append(shapes)
	return JSON.stringify(data)
func make_region(root_map: WorldMap2D, id: String, definition: String, title: String, center: Vector2, minimum: int, maximum: int, population: int) -> void:
	var region: WorldMonsterRegion=WorldMonsterRegion.new()
	region.name=id; region.stable_id=id; region.display_name=title
	region.monster=load("res://features/units/data/monsters/"+definition+".tres")
	region.minimum_level=minimum; region.maximum_level=maximum
	region.minimum_units=3 if definition=="millennium_worm" else 2
	region.maximum_units=5 if definition!="millennium_wolf" else 4
	region.party_count=population; region.aggressive=true; region.battlefields=PackedStringArray(["millennium_lake"])
	region.respawn_min_seconds=25; region.respawn_max_seconds=45
	region.position=Iso.project(center)
	root_map.get_node("MonsterRegions").add_child(region); region.owner=root_map
	region.set_meta("authoring_order",110+root_map.get_node("MonsterRegions").get_child_count())
	for name_text: String in ["SpawnArea","RoamingArea","PursuitArea"]:
		var area: WorldRegionPolygon=WorldRegionPolygon.new(); area.name=name_text
		var extent: Vector2=Vector2(220,180) if name_text=="SpawnArea" else Vector2(360,300) if name_text=="RoamingArea" else Vector2(480,400)
		var polygon: PackedVector2Array=[]
		for offset: Vector2 in [Vector2(-1,-1),Vector2(1,-1),Vector2(1,1),Vector2(-1,1)]: polygon.append(Iso.project(offset*extent*0.5))
		area.polygon=polygon
		region.add_child(area); area.owner=root_map
func _initialize() -> void:
	var root_map: WorldMap2D=(load(PATH) as PackedScene).instantiate() as WorldMap2D
	assert(not root_map.has_meta("millennium_ecology_v2"),"Do not overwrite Artist edits by rerunning authoring")
	var before: WorldMapDefinition=root_map.compile_definition()
	var stamp: String=geometry_stamp(before)
	var portal_stamp: String=JSON.stringify(before.portals)
	for node: Node in WorldAuthorTree.nodes(root_map):
		if node is WorldMonsterRegion and node.monster!=null and node.monster.id==&"lake_guardian":
			node.simple_party=true; node.minimum_level=50; node.maximum_level=50; node.minimum_units=1; node.maximum_units=1; node.party_count=1
			node.display_name="沉祠核心・千年龜守 Lv50 → 湖主 Lv99"
	make_region(root_map,"lake_worm_west","millennium_worm","西岸蟲群・Lv30–45",Vector2(400,760),30,45,5)
	make_region(root_map,"lake_worm_depth","millennium_worm","沼岸蟲窟・Lv45–60",Vector2(400,1010),45,60,5)
	make_region(root_map,"lake_worm_ancient","millennium_worm","南岸古蟲・Lv60–70",Vector2(610,1300),60,70,5)
	make_region(root_map,"lake_bird_north","millennium_bird","北堤火羽・Lv40–45",Vector2(800,260),40,45,4)
	make_region(root_map,"lake_bird_ridge","millennium_bird","北崖焚鳥・Lv46–52",Vector2(1160,270),46,52,4)
	make_region(root_map,"lake_bird_east","millennium_bird","東北火翼・Lv53–60",Vector2(1660,270),53,60,4)
	make_region(root_map,"lake_wolf_east","millennium_wolf","東岸狼群・Lv50–60",Vector2(1820,670),50,60,4)
	make_region(root_map,"lake_wolf_guard","millennium_wolf","東岸疾獵・Lv61–70",Vector2(1830,1030),61,70,4)
	make_region(root_map,"lake_wolf_alpha","millennium_wolf","南堤狼王・Lv71–80",Vector2(1310,1340),71,80,4)
	root_map.definition=root_map.definition.duplicate(true) as WorldMapDefinition
	root_map.definition.content_version=2
	root_map.set_meta("millennium_ecology_v2",true)
	WorldCatalog.initialize()
	var compiled: WorldMapDefinition=root_map.compile_definition()
	assert(geometry_stamp(compiled)==stamp and JSON.stringify(compiled.portals)==portal_stamp,"Preserve navigation and portals")
	var errors: Array[String]=WorldValidator.validate(compiled,WorldCatalog.definitions)
	assert(errors.is_empty(),"Invalid lake ecology: "+str(errors))
	var pack: PackedScene=PackedScene.new(); assert(pack.pack(root_map)==OK); assert(ResourceSaver.save(pack,PATH)==OK)
	print("MILLENNIUM_ECOLOGY regions=",compiled.habitats.size()," navigation and portals unchanged")
	root_map.free(); quit()
