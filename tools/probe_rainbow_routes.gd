extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var def: WorldMapDefinition = WorldCatalog.definitions.rainbow_temple
	var nav := WorldNavigationService.new(); nav.register_map(def)
	for point: Vector2 in [Vector2(1552,912),Vector2(1552,1392),Vector2(784,1488),Vector2(784,1776),Vector2(784,2224),Vector2(4000,2400)]:
		print("ROUTE ",point," ",nav.find_path(def.map_id,"","PLAYER",def.entries.entrance.point,point,16))
	quit()
