extends SceneTree
func _initialize() -> void:
	var river: WorldMap2D=load("res://features/world/data/river_bay.tscn").instantiate()
	var map: WorldMapDefinition=river.compile_definition()
	var nav:=WorldNavigationService.new(); nav.register_map(map)
	for canvas: Vector2 in [Vector2(1900,3850),Vector2(1800,3400),Vector2(2500,3300),Vector2(2000,3200),Vector2(3100,3900)]:
		var p: Vector2=Iso.unproject(canvas); var valid: bool=true
		for dx: int in [-50,0,50]:
			for dy: int in [-50,0,50]:
				var at: Vector2=p+Vector2(dx,dy)
				valid=valid and nav.segment_legal("river_bay","","PLAYER",at,at,16)
		for safe: PolygonDomain in map.safe_areas:
			if safe.contains(p): valid=false
		print("ZONE ",canvas," logical=",p," legal=",valid," path=",nav.find_path("river_bay","","PLAYER",map.entries.start.point,p,16).ok)
	river.free(); quit()
