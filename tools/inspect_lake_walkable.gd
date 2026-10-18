extends SceneTree
func _initialize() -> void:
	WorldCatalog.initialize()
	var map: WorldMapDefinition=WorldCatalog.definitions.millennium_lake
	var nav: WorldNavigationService=WorldNavigationService.new(); nav.register_map(map)
	print("LAKE_EXTENT ",map.extent)
	for h: WorldHabitat in map.habitats: print("REGION ",h.habitat_id," ",h.display_name," ",h.profile.target_party_count," ",h.spawn_domain.outer)
	for y: int in range(64,int(map.extent.y),96):
		var row: String=""
		for x: int in range(64,int(map.extent.x),96):
			var point: Vector2=Vector2(x,y)
			var safe: bool=map.safe_areas.any(func(d: PolygonDomain)->bool: return d.contains(point))
			row+="S" if safe else "." if nav.segment_legal(map.map_id,"","PLAYER",point,point,16) else "#"
		print(y,": ",row)
	quit()
