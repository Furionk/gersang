extends SceneTree
## Human specifically requested deletion of lake_guardian2; preserve central guardian and all terrain.
func _initialize() -> void:
	var path: String="res://features/world/data/millennium_lake.tscn"
	var scene: WorldMap2D=(load(path) as PackedScene).instantiate()
	var target: WorldMonsterRegion=scene.get_node_or_null("MonsterRegions/lake_guardian2")
	assert(target!=null and target.stable_id=="author_1f3a0eaf_6b5d3013700","Verify exact human-added region before removing")
	var old: WorldHabitat=target.compile_habitat(scene)
	old.profile=old.profile.duplicate(false); old.profile.target_party_count=0
	scene.definition=scene.definition.duplicate(false) as WorldMapDefinition
	scene.definition.retired_habitats=scene.definition.retired_habitats.duplicate()
	scene.definition.retired_habitats.append(old)
	scene.definition.content_version=3
	target.get_parent().remove_child(target); target.free()
	scene.set_meta("millennium_removed_added_guardian",true)
	WorldCatalog.initialize()
	var map: WorldMapDefinition=scene.compile_definition()
	assert(map.habitats.size()==10 and map.habitat("lake_guardian")!=null)
	assert(WorldValidator.validate(map,WorldCatalog.definitions).is_empty())
	var pack: PackedScene=PackedScene.new(); assert(pack.pack(scene)==OK); assert(ResourceSaver.save(pack,path)==OK)
	scene.free(); print("RETIRED_LAKE_GUARDIAN added region removed, central guardian retained"); quit()
