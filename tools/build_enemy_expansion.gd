extends SceneTree
## One-shot D25 authoring; never called at runtime. All original art is immutable.
var units: Dictionary = {}
var skills: Dictionary = {}
var audit: Dictionary = {}
const OUT: String = "res://artifacts/enemy-expansion-2026-10-10/"
func _initialize() -> void: call_deferred("run")
func save_resource(value: Resource, path: String) -> void:
	assert(ResourceSaver.save(value,path)==OK,"Cannot save "+path)
	value.take_over_path(path)
func make_skill(id: String, name_text: String, base: String, values: Dictionary) -> SkillDefinition:
	var skill: SkillDefinition = load("res://features/skills/data/"+base+".tres").duplicate(true) as SkillDefinition
	skill.id = StringName(id)
	skill.display_name = name_text
	skill.action = &""
	skill.default_key = KEY_NONE
	skill.ai_enabled = true
	skill.cooldown = 0.0
	for field: String in values: skill.set(field,values[field])
	save_resource(skill,"res://features/skills/data/enemies/"+id+".tres")
	skills[id] = load("res://features/skills/data/enemies/"+id+".tres")
	return skill
func make_unit(id: String, name_text: String, source: String, art: String, values: Dictionary, owned: Array[String]) -> UnitDefinition:
	var unit: UnitDefinition = load(UnitResourcePaths.canonical("res://features/units/data/"+source+".tres")).duplicate(true) as UnitDefinition
	unit.id = StringName(id)
	unit.display_name = name_text
	unit.content_revision = 1
	unit.skills.clear()
	unit.base_power = 240
	unit.level_power_growth = 24
	if not art.is_empty():
		unit.sprite_path = "res://features/units/art/"+art+"-v1.png"
		unit.sprite_layout = load("res://features/units/data/layouts/"+art+"_layout.tres")
	for field: String in values: unit.set(field,values[field])
	for skill_id: String in owned: unit.skills.append(skills[skill_id])
	var path: String = "res://features/units/data/"+("summons/" if id=="copper_reinforcement" else "monsters/")+id+".tres"
	save_resource(unit,path)
	units[id] = load(path)
	audit[id] = {"name":name_text,"file":path,"skills":owned,"art":unit.sprite_path,"stats":values}
	return unit
func run() -> void:
	if "--copper-v2" in OS.get_cmdline_user_args():
		author_layout("copper_monk","res://features/units/art/copper_monk-v2.png","res://features/units/data/layouts/copper_monk_v2_layout.tres")
		for id: String in ["copper_reinforcement","shaolin_copper_master"]:
			var path: String = "res://features/units/data/"+("summons/" if id=="copper_reinforcement" else "monsters/")+id+".tres"
			var local: UnitDefinition = load(path).duplicate(true) as UnitDefinition
			local.sprite_path = "res://features/units/art/copper_monk-v2.png"
			local.sprite_layout = load("res://features/units/data/layouts/copper_monk_v2_layout.tres")
			save_resource(local,path)
		print("COPPER_DEATH_ART_UPDATED")
		quit()
		return
	# Refuse partial authoring if any required source image is missing.
	for art: String in ["copper_monk","blood_wraith","tomb_pyromancer"]:
		assert(FileAccess.file_exists("res://features/units/art/"+art+"-v1.png"),"Missing generated atlas "+art)
	for id: String in ["river_bay","well_1","well_2","shaolin_temple"]:
		var root: WorldMap2D = load("res://features/world/data/"+id+".tscn").instantiate() as WorldMap2D
		assert(not root.has_meta("enemy_expansion_revision"),"Finalized scene; never overwrite artist edits")
		root.free()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://features/skills/data/enemies"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://features/units/data/monsters"))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://features/units/data/summons"))
	for art: String in ["copper_monk","blood_wraith","tomb_pyromancer"]: author_layout(art)
	make_skill("enemy_quake","震地術","quake",{"mana_cost":18.0,"cast_time":0.45,"ai_attempt_interval":3.0,"ai_cast_chance":0.25,"damage_formula":"strength*0.45","description":"在敵方位置震地，每0.25秒傷害一次；結束减速。AI每3秒判斷25%機率。"})
	make_skill("enemy_shockwave","裂焰衝擊波","dragon",{"mana_cost":20.0,"cast_time":0.35,"ai_attempt_interval":3.2,"ai_cast_chance":0.22,"damage_formula":"intelligence*0.35","description":"沿釋放方向射出寬60的衝擊波；可橫移避開。每3.2秒判斷22%機率。"})
	make_skill("enemy_critical","凶猛暴擊","critical",{"mana_cost":0.0,"ai_enabled":false,"proc_chance":0.18,"critical_multiplier_min":2.0,"critical_multiplier_max":3.0,"damage_formula":"attack","description":"普攻命中18%機率以2–3倍攻擊造成暴擊。"})
	make_skill("enemy_life_steal","噬血","critical",{"effect":SkillDefinition.Effect.LIFE_STEAL,"mana_cost":0.0,"ai_enabled":false,"proc_chance":1.0,"life_steal_ratio":0.30,"damage_formula":"0","description":"普攻命中後回復實際扣除HP的30%；MISS、過量傷害及已死施法者不吸血。"})
	var flame: SkillDefinition = make_skill("enemy_flame","焚地火焰","quake",{"effect":SkillDefinition.Effect.FLAME,"mana_cost":22.0,"cast_time":0.65,"range":330.0,"radius":85.0,"ai_attempt_interval":3.5,"ai_cast_chance":0.22,"damage_formula":"intelligence*0.30","description":"在目標位置留下4秒火焰，每0.5秒傷害；離開火區可避開。"})
	flame.effect_data.kind = SkillEffectDefinition.Kind.FLAME
	flame.effect_data.duration = 4.0
	flame.effect_data.tick_interval = 0.5
	flame.effect_data.radius = 85.0
	flame.effect_data.sprite_path = "res://features/skills/art/blast.png"
	save_resource(flame,"res://features/skills/data/enemies/enemy_flame.tres")
	skills["enemy_flame"] = load("res://features/skills/data/enemies/enemy_flame.tres")
	make_unit("copper_reinforcement","金身銅人","shaolin_guardian","copper_monk",{"max_health":380.0,"damage":24.0,"defense":12.0,"speed":115.0,"strength":35.0,"armor":0.15,"experience_reward":0},["enemy_critical"])
	var summon: SkillDefinition = make_skill("enemy_copper_summon","十八銅人陣","summon",{"target_mode":SkillDefinition.Target.SELF,"mana_cost":38.0,"cast_time":0.7,"range":360.0,"ai_attempt_interval":5.0,"ai_cast_chance":0.40,"damage_formula":"0","description":"召喚2–3名金身銅人，存活60秒；同一施法者只保留一組。銅人不給額外經驗／戰利品。"})
	summon.effect_data.summon_definition = units.copper_reinforcement
	summon.effect_data.summon_attack_bonus_formula = "0"
	summon.effect_data.summon_accuracy_bonus_formula = "0"
	summon.effect_data.summon_count_min = 2
	summon.effect_data.summon_count_max = 3
	summon.effect_data.summon_inherit_level = true
	summon.effect_data.duration = 60.0
	save_resource(summon,"res://features/skills/data/enemies/enemy_copper_summon.tres")
	skills.enemy_copper_summon = load("res://features/skills/data/enemies/enemy_copper_summon.tres")
	make_unit("bloodfang","噬血山魈","elite","blood_wraith",{"max_health":200.0,"damage":17.0,"speed":125.0,"strength":25.0,"experience_reward":45},["enemy_life_steal","enemy_critical"])
	make_unit("ember_raider","赤焰劫匪","archer","tomb_pyromancer",{"max_health":210.0,"max_mana":140.0,"damage":14.0,"intelligence":32.0,"attack_range":230.0,"speed":105.0,"experience_reward":55},["enemy_flame","enemy_shockwave"])
	make_unit("earth_brute","裂地石妖","elite","",{"max_health":310.0,"max_mana":110.0,"strength":38.0,"damage":21.0,"speed":92.0,"sprite_tint":Color(0.78,0.88,1.0),"experience_reward":65},["enemy_quake","enemy_critical"])
	make_unit("well_blood_wraith","古井血侍","elite","blood_wraith",{"max_health":270.0,"damage":23.0,"speed":118.0,"strength":32.0,"experience_reward":110},["enemy_life_steal","enemy_critical"])
	make_unit("well_earth_sentinel","古井震地鬼衛","elite","",{"max_health":340.0,"max_mana":130.0,"damage":24.0,"strength":45.0,"speed":88.0,"sprite_tint":Color(0.72,0.84,1.0),"experience_reward":120},["enemy_quake"])
	make_unit("well_pyromancer","古井燃燈巫","archer","tomb_pyromancer",{"max_health":250.0,"max_mana":170.0,"damage":18.0,"intelligence":44.0,"attack_range":250.0,"speed":105.0,"experience_reward":125},["enemy_flame","enemy_shockwave"])
	make_unit("deep_well_blood_wraith","深井嗜血刑鬼","elite","blood_wraith",{"max_health":380.0,"damage":33.0,"defense":15.0,"strength":48.0,"speed":132.0,"sprite_tint":Color(1.0,0.68,0.70),"experience_reward":320},["enemy_life_steal","enemy_critical"])
	make_unit("deep_well_shock_guard","深井裂焰鬼將","elite","",{"max_health":460.0,"max_mana":200.0,"damage":32.0,"strength":55.0,"intelligence":52.0,"defense":20.0,"speed":102.0,"sprite_tint":Color(0.68,0.80,1.0),"experience_reward":340},["enemy_quake","enemy_shockwave","enemy_critical"])
	make_unit("deep_well_pyromancer","深井焚魂祭司","archer","tomb_pyromancer",{"max_health":350.0,"max_mana":250.0,"damage":26.0,"intelligence":65.0,"attack_range":280.0,"speed":108.0,"magic_resistance":0.22,"experience_reward":350},["enemy_flame","enemy_shockwave"])
	make_unit("shaolin_copper_master","銅人陣師","shaolin_guardian","copper_monk",{"max_health":420.0,"max_mana":180.0,"damage":25.0,"strength":40.0,"defense":14.0,"speed":100.0,"experience_reward":150},["enemy_copper_summon","enemy_critical"])
	make_unit("shaolin_swift_disciple","疾影棍僧","shaolin_guardian","",{"max_health":240.0,"damage":20.0,"speed":245.0,"agility":45.0,"attack_interval":0.9,"sprite_tint":Color(1.0,0.85,0.65),"experience_reward":100},["enemy_critical"])
	make_unit("shaolin_flame_keeper","赤燈護法","shaolin_guardian","tomb_pyromancer",{"max_health":320.0,"max_mana":170.0,"damage":21.0,"intelligence":38.0,"attack_range":220.0,"speed":115.0,"experience_reward":130},["enemy_flame","enemy_quake"])
	for map_id: String in ["river_bay","well_1","well_2","shaolin_temple"]: configure_map(map_id)
	var file: FileAccess = FileAccess.open(OUT+"authored-enemies.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"decision":"D25","units":audit},"\t"))
	print("ENEMY_EXPANSION_AUTHORED units=",units.size()," skills=",skills.size())
	quit()

func configure_map(id: String) -> void:
	var path: String = "res://features/world/data/"+id+".tscn"
	var backup: String = OUT+"originals/features__world__data__"+id+".tscn"
	assert(FileAccess.get_sha256(path)==FileAccess.get_sha256(backup),"Concurrent scene edit; preserve and stop: "+id)
	var root: WorldMap2D = load(path).instantiate() as WorldMap2D
	root.definition = root.definition.duplicate(true) as WorldMapDefinition
	root.definition.content_version = 3
	for child: Node in WorldAuthorTree.nodes(root):
		if not child is WorldAuthorNode or child.kind!=WorldAuthorNode.Kind.HABITAT: continue
		var region: WorldAuthorNode = child
		# User-protected species identity: farm is always the authored boar herd.
		if id=="river_bay" and region.stable_id=="farm": continue
		region.habitat = region.habitat.duplicate(true) as WorldHabitat
		var profile: SpawnProfile = region.habitat.profile
		var selected: Array[String] = []
		var minimum: int = 6
		var maximum: int = 12
		if id=="well_1":
			selected = ["well_blood_wraith","well_earth_sentinel","well_pyromancer"]
			profile.target_party_count = 10
			minimum = 18; maximum = 24
		elif id=="well_2":
			selected = ["deep_well_blood_wraith","deep_well_shock_guard","deep_well_pyromancer"]
			profile.target_party_count = 14
			minimum = 45; maximum = 55
		elif id=="shaolin_temple":
			selected = ["shaolin_swift_disciple","shaolin_flame_keeper","shaolin_copper_master"]
			minimum = 10; maximum = 18
			if region.stable_id=="rear_patrol": minimum = 16; maximum = 22
		elif id=="river_bay":
			selected = ["bloodfang","ember_raider","earth_brute"]
			if region.stable_id in ["forest","mountain"]: minimum = 10; maximum = 16
		profile.templates.clear()
		for variant: int in 2:
			var template: PartyTemplate = PartyTemplate.new()
			template.template_id = region.stable_id+"_d25_"+str(variant)
			template.display_name = region.display_name+ (" · 巡獵" if variant==0 else " · 術陣")
			template.representative = units[selected[variant]]
			for index: int in selected.size():
				var member: MemberRule = MemberRule.new()
				member.definition = units[selected[index]]
				member.min_count = 1
				member.max_count = 2 if id=="well_2" or (id=="well_1" and index==variant) else 1
				member.min_level = minimum
				member.max_level = maximum
				template.members.append(member)
			profile.templates.append(template)
		profile.weights = PackedFloat32Array([3.0,2.0])
		if region is WorldMonsterRegion:
			var native_region: WorldMonsterRegion = region as WorldMonsterRegion
			native_region.simple_party = false
			native_region.party_count = profile.target_party_count
			native_region.minimum_level = minimum
			native_region.maximum_level = maximum
			native_region.monster = profile.templates[0].representative
	root.set_meta("enemy_expansion_revision",1)
	var packed: PackedScene = PackedScene.new()
	assert(packed.pack(root)==OK)
	save_resource(packed,path)
	root.free()

func author_layout(art: String, source_path: String = "", layout_path: String = "") -> void:
	var image: Image = Image.load_from_file(source_path if not source_path.is_empty() else "res://features/units/art/"+art+"-v1.png")
	assert(image!=null and not image.is_empty())
	image.convert(Image.FORMAT_RGBA8)
	var bytes: PackedByteArray = image.get_data()
	var width: int = image.get_width()
	var height: int = image.get_height()
	var visited: PackedByteArray = PackedByteArray()
	visited.resize(width*height)
	var components: Array[Dictionary] = []
	for start: int in width*height:
		if visited[start]!=0 or bytes[start*4+3]<32: continue
		visited[start] = 1
		var queue: Array[int] = [start]
		var cursor: int = 0
		var lo: Vector2i = Vector2i(start%width,start/width)
		var hi: Vector2i = lo
		var center: Vector2 = Vector2.ZERO
		while cursor<queue.size():
			var pixel: int = queue[cursor]; cursor+=1
			var x: int = pixel%width
			var y: int = pixel/width
			lo = lo.min(Vector2i(x,y)); hi = hi.max(Vector2i(x,y))
			center += Vector2(x,y)
			for neighbor: int in [pixel-1 if x>0 else -1,pixel+1 if x<width-1 else -1,pixel-width if y>0 else -1,pixel+width if y<height-1 else -1]:
				if neighbor<0 or visited[neighbor]!=0 or bytes[neighbor*4+3]<32: continue
				visited[neighbor] = 1
				queue.append(neighbor)
		if queue.size()>800: components.append({"rect":Rect2i(lo,hi-lo+Vector2i.ONE).grow(2).intersection(Rect2i(0,0,width,height)),"center":center/float(queue.size()),"pixels":queue.size()})
	var selected: Array[Rect2i] = []
	var used: Dictionary = {}
	var cell: Vector2 = Vector2(width/6.0,height/8.0)
	for row: int in 8:
		for column: int in 6:
			var expected: Vector2 = Vector2(column+0.5,row+0.6)*cell
			var best: int = -1
			var distance: float = INF
			for index: int in components.size():
				if used.has(index): continue
				var offset: Vector2 = components[index].center-expected
				if absf(offset.x)>cell.x*0.8 or absf(offset.y)>cell.y*0.8: continue
				if offset.length_squared()<distance: best=index; distance=offset.length_squared()
			assert(best>=0,"Missing complete silhouette "+art+" row="+str(row)+" col="+str(column))
			used[best] = true
			selected.append(components[best].rect)
	var layout: SpriteSheetLayout = SpriteSheetLayout.new()
	layout.source_size = Vector2i(width,height)
	layout.frame_size = Vector2i(320,256)
	layout.foot_point = Vector2(160,226)
	layout.frame_rects = selected
	if art=="copper_monk": layout.direction_rows = [0,0,1,3,4,7,6,5]
	for row: int in 8:
		var baseline: float = float(selected[row*6].end.y+selected[row*6+1].end.y+selected[row*6+2].end.y)/3.0-2.0
		for column: int in 6:
			var rect: Rect2i = selected[row*6+column]
			layout.source_pivots.append(Vector2((column+0.5)*cell.x,baseline)-Vector2(rect.position))
	assert(layout.valid_for(Vector2i(width,height)),"Invalid authored atlas "+art)
	save_resource(layout,layout_path if not layout_path.is_empty() else "res://features/units/data/layouts/"+art+"_layout.tres")
	print("AUTHORED_LAYOUT ",art," components=",components.size()," source=",layout.source_size)
