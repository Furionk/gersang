extends SceneTree
func _initialize() -> void:
	var path: String = "res://features/world/data/river_bay.tscn"
	var root_map: WorldMap2D = load(path).instantiate() as WorldMap2D
	assert(not root_map.has_meta("farm_boar_revision"),"Already finalized; do not overwrite artist edits")
	var farm: WorldMonsterRegion = root_map.get_node("MonsterRegions/farm") as WorldMonsterRegion
	assert(farm!=null)
	var boar: UnitDefinition = load("res://features/units/data/monsters/beast.tres") as UnitDefinition
	assert(boar.sprite_path=="res://features/units/art/beast.png")
	farm.simple_party = true
	farm.monster = boar
	farm.party_count = 12
	farm.minimum_units = 6
	farm.maximum_units = 9
	farm.minimum_level = 6
	farm.maximum_level = 12
	farm.habitat = farm.habitat.duplicate(true) as WorldHabitat
	var template: PartyTemplate = PartyTemplate.new()
	template.template_id = "farm_boars_v4"
	template.display_name = "租霸豬"
	template.representative = boar
	var member: MemberRule = MemberRule.new()
	member.definition = boar
	member.min_count = 6; member.max_count = 9
	member.min_level = 6; member.max_level = 12
	template.members = [member]
	farm.habitat.profile.templates = [template]
	farm.habitat.profile.weights = PackedFloat32Array([1.0])
	farm.habitat.profile.target_party_count = 12
	root_map.definition = root_map.definition.duplicate(true) as WorldMapDefinition
	root_map.definition.content_version = 4
	root_map.set_meta("farm_boar_revision",1)
	assert(FileAccess.get_sha256(path)==FileAccess.get_sha256("res://artifacts/boar-fix-2026-10-10/river_bay-before.tscn"),"Concurrent artist edit; stop")
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(root_map)==OK and ResourceSaver.save(packed,path)==OK)
	root_map.free()
	print("FARM_BOARS_AUTHORED 12 parties,6–9 boars each; only farm profile changed")
	quit()
