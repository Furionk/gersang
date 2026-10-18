extends SceneTree
func _initialize()->void:call_deferred("run")
func texture_key(texture:Texture2D)->Array:
	if texture==null:return []
	if texture is AtlasTexture:return [texture_key(texture.atlas),texture.region,texture.margin,texture.filter_clip]
	return [texture.resource_path,texture.get_size()]
func geometry(map:WorldMapDefinition)->Array:
	var values:Array=[]
	for collection:Array[PolygonDomain] in [map.walkable,map.blockers]:
		var shapes:Array=[]
		for domain:PolygonDomain in collection:shapes.append([domain.outer,domain.holes,domain.visual_kind])
		values.append(shapes)
	return values
func run()->void:
	var before:WorldMap2D=load("res://artifacts/hogwarts-2026-10-13/before/river_bay.tscn").instantiate()
	var after:WorldMap2D=load("res://features/world/data/river_bay.tscn").instantiate()
	var a:WorldMapDefinition=before.compile_definition();var b:WorldMapDefinition=after.compile_definition()
	var changed:Array[String]=[]
	if geometry(a)!=geometry(b):changed.append("navigation geometry")
	for entry:String in a.entries:
		if a.entries[entry]!=b.entries.get(entry):changed.append("entry "+entry)
	for portal:Dictionary in a.portals:
		if not b.portals.has(portal):changed.append("portal "+portal.id)
	for node:Node in WorldAuthorTree.nodes(before):
		var other:Node=after.get_node_or_null(before.get_path_to(node))
		if other==null:changed.append("removed "+str(node.name));continue
		if node is Node2D and node.transform!=other.transform:changed.append("transform "+str(node.name))
		if node is Sprite2D:
			for property:String in ["texture","offset","centered","region_enabled","region_rect","flip_h","flip_v","modulate","z_index"]:
				if property=="texture":
					if texture_key(node.texture)!=texture_key(other.texture):changed.append("texture "+str(node.name))
				elif node.get(property)!=other.get(property):changed.append(property+" "+str(node.name))
	before.free();after.free()
	var report:Dictionary={"unchanged":changed.is_empty(),"differences":changed,"new_portals":b.portals.size()-a.portals.size(),"new_entries":b.entries.size()-a.entries.size()}
	var file:FileAccess=FileAccess.open("res://artifacts/tests/hogwarts/preservation.json",FileAccess.WRITE);file.store_string(JSON.stringify(report,"\t"));file.close()
	print("HOGWARTS_PRESERVATION ",JSON.stringify(report));quit(0 if changed.is_empty() else 1)
