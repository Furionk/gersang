extends SceneTree
func _initialize() -> void:
	WorldCatalog.initialize()
	for id: String in WorldCatalog.definitions:
		var errors: Array[String] = WorldValidator.validate(WorldCatalog.definitions[id],WorldCatalog.definitions)
		print("CURRENT_WORLD_VALIDATION ",id," ",JSON.stringify(errors))
	quit()
