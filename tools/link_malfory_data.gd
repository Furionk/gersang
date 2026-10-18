extends SceneTree
func _initialize() -> void:
	var unit: UnitDefinition=load("res://features/units/data/mercenaries/malfory.tres")
	if unit.get_meta("malfory_link_finalized",false):
		print("SKIP finalized artist unit"); quit(); return
	unit.skills=[load("res://features/skills/data/crucio.tres"),load("res://features/skills/data/avada_kedavra.tres")]
	unit.sprite_layout=load("res://features/units/data/layouts/malfory_layout.tres")
	unit.set_meta("malfory_link_finalized",true)
	assert(ResourceSaver.save(unit,unit.resource_path)==OK)
	print("MALFORY_NATIVE_LINKS_EXTERNAL")
	quit()
