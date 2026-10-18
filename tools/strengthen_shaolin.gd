extends SceneTree
var definitions: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func variant(id: String, title: String, base: String, stats: Dictionary, skills: Array[String]) -> void:
	var unit: UnitDefinition = load(UnitResourcePaths.canonical("res://features/units/data/"+base+".tres")).duplicate(true) as UnitDefinition
	unit.id = StringName(id); unit.display_name = title
	unit.skills.clear()
	for field: String in stats: unit.set(field,stats[field])
	for skill: String in skills: unit.skills.append(load("res://features/skills/data/enemies/"+skill+".tres"))
	var path: String = "res://features/units/data/monsters/"+id+".tres"
	assert(ResourceSaver.save(unit,path)==OK)
	unit.take_over_path(path)
	definitions[id] = unit
func template(id: String, title: String, members: Array) -> PartyTemplate:
	var party: PartyTemplate = PartyTemplate.new()
	party.template_id = id; party.display_name = title
	for data: Array in members:
		var rule: MemberRule = MemberRule.new()
		rule.definition = definitions[data[0]]
		rule.min_count=data[1]; rule.max_count=data[2]; rule.min_level=data[3]; rule.max_level=data[4]
		party.members.append(rule)
	party.representative = party.members[0].definition
	return party
func configure(region: WorldMonsterRegion, count: int, title: String, parties: Array[PartyTemplate], weights: PackedFloat32Array, low: int, high: int) -> void:
	region.habitat = region.habitat.duplicate(true) as WorldHabitat
	region.simple_party = false
	region.party_count = count
	region.display_name = title
	region.minimum_level=low; region.maximum_level=high
	region.habitat.profile.templates = parties
	region.habitat.profile.weights = weights
	region.habitat.profile.target_party_count = count
	region.monster = parties[0].representative
func run() -> void:
	var path: String = "res://features/world/data/shaolin_temple.tscn"
	var root_map: WorldMap2D = load(path).instantiate() as WorldMap2D
	assert(not root_map.has_meta("shaolin_strength_revision"),"Already authored; preserve future artist edits")
	assert(FileAccess.get_sha256(path)==FileAccess.get_sha256("res://artifacts/shaolin-strength-2026-10-10/before.tscn"),"Concurrent scene edit")
	for id: String in ["shaolin_swift_disciple","shaolin_flame_keeper","shaolin_copper_master"]:
		definitions[id] = load("res://features/units/data/monsters/"+id+".tres")
	variant("shaolin_iron_disciple","鐵棍武僧","shaolin_guardian",{"max_health":320.0,"damage":23.0,"strength":32.0,"defense":10.0,"armor":0.10,"experience_reward":100,"base_power":280},[])
	variant("shaolin_shadow_captain","疾影統領","enemies/shaolin_swift_disciple",{"max_health":420.0,"damage":32.0,"speed":270.0,"agility":65.0,"defense":16.0,"armor":0.08,"base_power":480,"experience_reward":230,"sprite_tint":Color(0.80,0.90,1.0)},["enemy_critical","enemy_life_steal"])
	variant("shaolin_thunder_warden","震地護法","enemies/shaolin_flame_keeper",{"max_health":470.0,"max_mana":260.0,"damage":29.0,"strength":55.0,"intelligence":58.0,"defense":18.0,"attack_range":250.0,"base_power":500,"experience_reward":250,"sprite_tint":Color(0.78,0.86,1.0)},["enemy_quake","enemy_shockwave"])
	variant("shaolin_elite_copper","金剛陣師","enemies/shaolin_copper_master",{"max_health":640.0,"max_mana":260.0,"damage":36.0,"strength":55.0,"defense":25.0,"armor":0.18,"base_power":650,"experience_reward":300},["enemy_copper_summon","enemy_critical"])
	variant("shaolin_grandmaster","金身羅漢","enemies/shaolin_copper_master",{"level":50,"role":10,"max_health":850.0,"max_mana":330.0,"damage":46.0,"strength":68.0,"intelligence":62.0,"defense":32.0,"armor":0.22,"magic_resistance":0.25,"speed":145.0,"base_power":1500,"level_power_growth":40,"experience_reward":650,"sprite_tint":Color(1.0,0.95,0.70)},["enemy_copper_summon","enemy_shockwave","enemy_critical"])
	var front: WorldMonsterRegion = root_map.get_node("MonsterRegions/front_patrol")
	var middle: WorldMonsterRegion = root_map.get_node("MonsterRegions/bronze_guardian")
	var rear: WorldMonsterRegion = root_map.get_node("MonsterRegions/rear_patrol")
	configure(front,10,"前庭 · 巡值武僧",[
		template("shaolin_front_guard","巡值武僧 · Lv12–18",[["shaolin_iron_disciple",3,5,12,18],["shaolin_swift_disciple",1,2,14,20]]),
		template("shaolin_front_flame","赤燈巡院 · Lv16–22",[["shaolin_flame_keeper",1,2,16,22],["shaolin_iron_disciple",3,4,14,20]])
	],PackedFloat32Array([3,1]),12,22)
	configure(middle,12,"演武院 · 精英試煉",[
		template("shaolin_middle_shadow","疾影精英 · Lv24–32",[["shaolin_shadow_captain",2,3,26,32],["shaolin_swift_disciple",2,4,24,30]]),
		template("shaolin_middle_wardens","震地術陣 · Lv28–36",[["shaolin_thunder_warden",1,2,30,36],["shaolin_flame_keeper",1,2,28,34],["shaolin_iron_disciple",2,3,28,34]]),
		template("shaolin_middle_copper","銅人試煉 · Lv28–36",[["shaolin_copper_master",1,2,30,36],["shaolin_iron_disciple",3,5,28,34]])
	],PackedFloat32Array([2,2,1]),24,36)
	configure(rear,6,"後院 · 金剛禁地",[
		template("shaolin_rear_vajra","金剛護衛 · Lv38–46",[["shaolin_elite_copper",1,2,42,46],["shaolin_shadow_captain",2,3,38,44],["shaolin_thunder_warden",1,2,40,46]]),
		template("shaolin_rear_flame","焚院護法 · Lv40–48",[["shaolin_thunder_warden",2,3,44,48],["shaolin_flame_keeper",2,3,40,46],["shaolin_shadow_captain",1,2,42,46]])
	],PackedFloat32Array([3,2]),38,48)
	var core: WorldMonsterRegion = rear.duplicate() as WorldMonsterRegion
	core.name = "inner_masters"
	core.stable_id = "inner_masters"
	root_map.get_node("MonsterRegions").add_child(core)
	core.owner = root_map
	for node: Node in WorldAuthorTree.nodes(core): node.owner = root_map
	configure(core,2,"核心 · 羅漢首領",[
		template("shaolin_lv50_master","金身羅漢 · Lv50",[["shaolin_grandmaster",1,1,50,50],["shaolin_elite_copper",2,3,44,48],["shaolin_shadow_captain",1,2,42,46]])
	],PackedFloat32Array([1]),42,50)
	core.set_meta("authoring_order",100)
	root_map.definition = root_map.definition.duplicate(true) as WorldMapDefinition
	root_map.definition.content_version = 4
	root_map.set_meta("shaolin_strength_revision",1)
	WorldCatalog.initialize()
	var compiled: WorldMapDefinition = root_map.compile_definition()
	var errors: Array[String] = WorldValidator.validate(compiled,WorldCatalog.definitions)
	assert(errors.is_empty(),"Invalid temple authoring: "+str(errors))
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(root_map)==OK and ResourceSaver.save(packed,path)==OK)
	root_map.free()
	print("SHAOLIN_STRENGTH_AUTHORED 30 parties,4 regions,8 archetypes,2 guaranteed Lv50 leaders")
	quit()
