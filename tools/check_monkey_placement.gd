extends SceneTree
func _initialize() -> void:
	var river: WorldMap2D=load("res://features/world/data/river_bay.tscn").instantiate()
	var definition: WorldMapDefinition=river.compile_definition()
	var nav:=WorldNavigationService.new(); nav.register_map(definition)
	for center: Vector2 in [Vector2(5000,2700),Vector2(5200,2500),Vector2(4800,2700)]:
		var valid: bool=true
		for dx: int in [-65,0,65]:
			for dy: int in [-65,0,65]:
				var p: Vector2=center+Vector2(dx,dy)
				valid=valid and nav.segment_legal("river_bay","","PLAYER",p,p,16)
		print("PLACEMENT ",center," legal=",valid," route=",nav.find_path("river_bay","","PLAYER",definition.entries.start.point,center,16).ok)
	quit()
