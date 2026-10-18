@tool
class_name WorldTileCompiler
extends RefCounted
static func apply(map: WorldMapDefinition, root: Node) -> void:
	map.native_tile_layers.clear()
	map.tile_authoring_errors.clear()
	map.walkable.clear()
	map.blockers.clear()
	map.safe_areas.clear()
	var layers: Array[WorldTileLayer] = []
	var polygon_regions: Dictionary = {}
	for child: Node in WorldAuthorTree.nodes(root):
		if child is WorldTileLayer: layers.append(child)
		if child is WorldMonsterRegion and child.shape_source==WorldMonsterRegion.ShapeSource.POLYGON: polygon_regions[child.stable_id] = true
	# Existing brush masks remain an explicit alternative, never a second authority.
	for child: Node in WorldAuthorTree.nodes(root,true):
		if child is WorldTileLayer and child.role>=WorldTileLayer.Role.SPAWN and not polygon_regions.has(child.region_id) and map.habitat(child.region_id)!=null and not layers.has(child): layers.append(child)
	for layer: WorldTileLayer in layers:
		if layer.tile_set==null or layer.tile_set.tile_shape!=TileSet.TILE_SHAPE_ISOMETRIC or layer.tile_set.tile_layout!=TileSet.TILE_LAYOUT_DIAMOND_DOWN or layer.tile_set.tile_size!=Vector2i(64,32) or layer.position!=Vector2(-32,0) or not layer.scale.is_equal_approx(Vector2.ONE) or not is_zero_approx(layer.rotation) or layer.logical_cell_size!=32 or not layer.enabled:
			map.tile_authoring_errors.append(str(layer.name)+": 使用 64×32 等角格、位置 (-32,0)、比例 1、旋轉 0，保持 Enabled。")
			continue
		match layer.role:
			WorldTileLayer.Role.GROUND:
				map.native_tile_layers.append(layer.snapshot())
				map.blockers.append_array(layer.geometry(true))
			WorldTileLayer.Role.OBSTACLES:
				map.native_tile_layers.append(layer.snapshot())
				map.blockers.append_array(layer.geometry())
			WorldTileLayer.Role.WALKABLE: map.walkable.append_array(layer.geometry())
			WorldTileLayer.Role.SAFE: map.safe_areas.append_array(layer.geometry())
			_:
				if polygon_regions.has(layer.region_id): continue
				var habitat: WorldHabitat = map.habitat(layer.region_id)
				if habitat==null:
					map.tile_authoring_errors.append("Tile mask has no habitat: "+str(layer.name)+" / "+layer.region_id)
					continue
				var domains: Array[PolygonDomain] = layer.geometry()
				var domain: PolygonDomain = domains[0] if domains.size()==1 else PolygonDomain.new()
				if domains.size()>1: map.tile_authoring_errors.append("Habitat tile mask must be connected: "+str(layer.name))
				if layer.role==WorldTileLayer.Role.SPAWN: habitat.spawn_domain = domain
				elif layer.role==WorldTileLayer.Role.ACTIVITY: habitat.activity_domain = domain
				else: habitat.chase_domain = domain
	for habitat: WorldHabitat in map.habitats:
		if polygon_regions.has(habitat.habitat_id): continue
		for role: int in [WorldTileLayer.Role.SPAWN,WorldTileLayer.Role.ACTIVITY,WorldTileLayer.Role.CHASE]:
			var matches: int = 0
			for layer: WorldTileLayer in layers:
				if layer.role==role and layer.region_id==habitat.habitat_id: matches+=1
			if matches!=1: map.tile_authoring_errors.append(habitat.habitat_id+": 每種怪區遮罩必須剛好一層，role="+str(role))
