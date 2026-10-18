extends SceneTree
const OUT: String="res://artifacts/demo-web-2026-10-11/"
func intersect_set(a: PolygonDomain,b: PolygonDomain) -> PolygonDomain:
	var contours: Array[PackedVector2Array]=Geometry2D.intersect_polygons(a.outer,b.outer)
	var cuts: Array[PackedVector2Array]=[]
	for hole: PackedVector2Array in a.holes+b.holes:
		if not cuts.any(func(existing: PackedVector2Array)->bool:return existing==hole): cuts.append(hole)
	var merging: bool=true
	while merging:
		merging=false
		for i: int in cuts.size():
			for j: int in range(i+1,cuts.size()):
				var union: Array[PackedVector2Array]=Geometry2D.merge_polygons(cuts[i],cuts[j])
				if union.size()==1:
					cuts[i]=union[0]; cuts.remove_at(j); merging=true; break
			if merging: break
	var holes: Array[PackedVector2Array]=[]
	for hole: PackedVector2Array in cuts:
		var remaining: Array[PackedVector2Array]=[]
		for contour: PackedVector2Array in contours:
			for piece: PackedVector2Array in Geometry2D.clip_polygons(contour,hole):
				if Geometry2D.is_polygon_clockwise(piece): holes.append(piece)
				else: remaining.append(piece)
		contours=remaining
	assert(not contours.is_empty())
	contours.sort_custom(func(x: PackedVector2Array,y: PackedVector2Array)->bool:return PolygonDomain.area(x)>PolygonDomain.area(y))
	var result: PolygonDomain=PolygonDomain.new(); result.outer=contours[0]
	var outer: PolygonDomain=PolygonDomain.new(); outer.outer=result.outer
	for hole: PackedVector2Array in holes:
		if outer.covers(hole): result.holes.append(hole)
	return result
func write_domain(node: WorldRegionPolygon,root: Node,domain: PolygonDomain) -> void:
	var inverse: Transform2D=WorldAuthorTree.canvas_transform(node,root).affine_inverse()
	var outer_points: PackedVector2Array=[]
	for point: Vector2 in domain.outer: outer_points.append(inverse*Iso.project(point)-node.offset)
	node.polygon=outer_points
	for child: Node in node.get_children():
		if child is WorldRegionPolygon and child.is_hole: node.remove_child(child); child.free()
	for i: int in domain.holes.size():
		var cut: WorldRegionPolygon=WorldRegionPolygon.new(); cut.name="Exclusion_%d"%i; cut.is_hole=true; node.add_child(cut); cut.owner=root
		var cut_points: PackedVector2Array=[]
		for point: Vector2 in domain.holes[i]: cut_points.append(inverse*Iso.project(point)-node.offset)
		cut.polygon=cut_points
func plain(value: Variant) -> Variant:
	if value is Resource: return value.resource_path
	if value is Dictionary:
		var copy: Dictionary={}; var keys: Array=value.keys(); keys.sort()
		for key: Variant in keys: copy[key]=plain(value[key])
		return copy
	if value is Array:
		var copy: Array=[]
		for entry: Variant in value: copy.append(plain(entry))
		return copy
	return value
func stamp(map: WorldMapDefinition) -> String:
	var values: Array=[]
	for domain: PolygonDomain in map.walkable+map.blockers: values.append([domain.outer,domain.holes])
	values.append(map.entries)
	values.append(map.portals)
	for entry: Dictionary in map.scenery:
		var safe: Dictionary=entry.duplicate()
		for key: Variant in safe:
			if safe[key] is Resource: safe[key]=safe[key].resource_path
		values.append(safe)
	return var_to_bytes(plain(values)).hex_encode().sha256_text()
func _initialize() -> void:
	WorldCatalog.initialize(); DirAccess.make_dir_recursive_absolute(OUT)
	for pair: Array in [["river_bay","forest"],["well_1","cave_hunt"]]:
		var path: String="res://features/world/data/"+pair[0]+".tscn"
		var backup: String=OUT+pair[0]+"-before.tscn.txt"
		if not FileAccess.file_exists(backup):
			var file: FileAccess=FileAccess.open(backup,FileAccess.WRITE); file.store_string(FileAccess.get_file_as_string(path)); file.close()
		var root: WorldMap2D=load(path).instantiate()
		if root.get_meta("demo_domain_repaired",false): root.free(); continue
		# Existing equal sort keys are unstable when the node count changes.
		# Freeze the original traversal order before adding/replacing exclusions.
		var order: Array[Node]=WorldAuthorTree.nodes(root)
		for i: int in order.size(): order[i].set_meta("authoring_order",i)
		var before: WorldMapDefinition=root.compile_definition()
		var region: WorldMonsterRegion
		for node: Node in WorldAuthorTree.nodes(root):
			if node is WorldMonsterRegion and node.stable_id==pair[1]: region=node; break
		assert(region!=null and region.shape_source==WorldMonsterRegion.ShapeSource.POLYGON)
		var current: WorldHabitat=region.compile_habitat(root)
		var chase: PolygonDomain=intersect_set(current.chase_domain,current.chase_domain)
		var activity: PolygonDomain=intersect_set(current.activity_domain,chase)
		var spawn: PolygonDomain=intersect_set(current.spawn_domain,activity)
		write_domain(region.get_node("PursuitArea"),root,chase)
		write_domain(region.get_node("RoamingArea"),root,activity)
		write_domain(region.get_node("SpawnArea"),root,spawn)
		var after: WorldMapDefinition=root.compile_definition()
		if stamp(before)!=stamp(after):
			print("PRESERVE_DIAGNOSTIC entries=",before.entries==after.entries," portals=",plain(before.portals)==plain(after.portals)," scenery=",plain(before.scenery)==plain(after.scenery))
			for i: int in mini(before.walkable.size(),after.walkable.size()): print("WALK ",i," ",before.walkable[i].outer==after.walkable[i].outer," ",before.walkable[i].holes==after.walkable[i].holes)
			for i: int in mini(before.blockers.size(),after.blockers.size()): print("BLOCK ",i," ",before.blockers[i].outer==after.blockers[i].outer," ",before.blockers[i].holes==after.blockers[i].holes)
			print("SCENERY_COUNTS ",before.scenery.size()," ",after.scenery.size())
			for i: int in mini(before.scenery.size(),after.scenery.size()):
				if plain(before.scenery[i])!=plain(after.scenery[i]):
					print("SCENERY_DIFF ",i," ",plain(before.scenery[i])," -> ",plain(after.scenery[i])); break
		assert(stamp(before)==stamp(after),"No visual/portal/player navigation changes")
		var errors: Array[String]=WorldValidator.validate(after,WorldCatalog.definitions)
		print("DOMAIN_VALIDATION ",pair[0]," ",errors)
		assert(errors.is_empty())
		root.set_meta("demo_domain_repaired",true)
		var packed: PackedScene=PackedScene.new(); assert(packed.pack(root)==OK); assert(ResourceSaver.save(packed,path)==OK)
		print("DEMO_DOMAIN_REPAIRED ",pair[0],"/",pair[1]); root.free()
	quit()
