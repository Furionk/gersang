extends "res://tools/expand_rainbow_dungeon.gd"
## New additive author pass. Never invokes the inherited original expansion.
const LEVELS := [25,50,75,90]
const ZONES := ["灰燼墓廊","雙首獸巢","赤焰祭壇","黑曜熔爐","熔翼迴廊","四印聖所","崩裂深淵","八燼祭殿","絕望龍巢"]
func run() -> void:
	var world: WorldMap2D = load(WORLD).instantiate()
	if world.has_meta("rainbow_branch_v3"):
		push_error("Branch dungeon already authored; refusing overwrite."); world.free(); quit(1); return
	var settings: RainbowActionProfile = load("res://features/rainbow/data/default_action.tres")
	for id: String in ["temple_hellhound","temple_double_hound","temple_lava_troll","temple_lava_bat"]:
		settings.enemies.append(load("res://features/rainbow/data/enemies/%s.tres" % id))
	var regions: Node = world.get_node("MonsterRegions")
	for tier: int in 4:
		var config := RainbowBossTier.new()
		config.tier = tier; config.recommended_level = LEVELS[tier]
		config.display_name = ["簡單","普通","中階","進階絕望"][tier]
		config.interval = [4.5,3.5,2.6,1.8][tier]
		if tier >= 1: config.attack_pool.append("sweep"); config.weights.append(3)
		if tier >= 2: config.attack_pool.append("trail"); config.weights.append(3)
		if tier >= 3: config.attack_pool.append("spiral"); config.weights.append(4)
		save(config,"res://features/rainbow/data/dragon_tier_%d.tres" % tier)
		for species: String in ["fire_dragon","lava_priest"]:
			var id: String = species if tier == 0 else species + "_tier_%d" % tier
			var unit: UnitDefinition = load("res://features/units/data/monsters/%s.tres" % species)
			var enemy: RainbowEnemyDefinition = load("res://features/rainbow/data/enemies/%s.tres" % species)
			if tier > 0:
				unit = unit.duplicate(); enemy = enemy.duplicate(true)
				unit.id = id; enemy.unit_id = id; enemy.weapon.unit_id = id
				unit.level = LEVELS[tier]
				unit.display_name = config.display_name + ("火龍" if species == "fire_dragon" else "熔岩祭司")
				unit.tactical_hint = "建議十人編隊 Lv%d · 自由挑戰 · 高危險；留意預警，側移與反擊。" % LEVELS[tier]
				settings.enemies.append(enemy)
			if species == "fire_dragon": enemy.boss_tier = config
			save(unit,"res://features/units/data/monsters/%s.tres" % id)
			save(enemy,"res://features/rainbow/data/enemies/%s.tres" % id)
			if tier > 0:
				var base := Vector2(116*32,(60+(tier-1)*52)*32)
				var priest: bool = species == "lava_priest"
				region(regions,id,"挑戰入口 · %s · Lv%d · %d隻" % [unit.display_name,LEVELS[tier],(1<<tier) if priest else 1],unit,Rect2(base+Vector2(160,160 if priest else 650),Vector2(700,220)),1,(1<<tier) if priest else 1,LEVELS[tier],"rainbow_sanctum" if priest else "rainbow_throne")
	# Four old halls form the connected introductory three-zone route and dragon annex.
	# Preserve all existing cells, stable IDs, entrance and safe return positions.
	var ground: WorldTileLayer = world.get_node("Ground/Ground_TileMap")
	var mask: WorldTileLayer = world.get_node("Ground/Walkable_Mask")
	var walls: WorldTileLayer = world.get_node("Ground/Obstacles_TileMap")
	for x: int in 160:
		for y: int in range(44,200):
			var cell := Vector2i(x,y)
			var walkable: bool = false
			for row: int in 3:
				var top: int = 60 + row*52
				for col: int in 3:
					if Rect2i(4+col*56,top,40,32).has_point(cell): walkable = true
				if Rect2i(24,top+14,112,5).has_point(cell): walkable = true
			# Two long side routes and crossbars produce loops and shortcuts.
			if x in range(22,27) or x in range(134,139): walkable = walkable or y < 192
			ground.set_cell(cell,0,Vector2i(posmod(x,8)+(0 if walkable else 8),1+posmod(y,8)))
			if walkable: mask.set_cell(cell,0,Vector2i.ZERO); walls.erase_cell(cell)
			else: walls.set_cell(cell,0,Vector2i(2,0)); mask.erase_cell(cell)
	# Extend two existing halls down to the new loops without disturbing old pillars.
	for x: int in [24,136]:
		for y: int in range(30,45):
			for dx: int in range(-2,3):
				var cell := Vector2i(x+dx,y)
				ground.set_cell(cell,0,Vector2i(posmod(cell.x,8),1+posmod(y,8)))
				mask.set_cell(cell,0,Vector2i.ZERO); walls.erase_cell(cell)
	for zone: int in 9:
		var row: int = zone / 3
		var col: int = zone % 3
		var origin := Vector2((4+col*56)*32,(60+row*52)*32)
		var title: String = "%s · 建議 Lv%d · 自由深入" % [ZONES[zone],LEVELS[row+1]]
		var marker := WorldAuthorNode.new()
		marker.name = "BranchZone%d" % zone; marker.stable_id = "rainbow_zone_%d" % (zone+3)
		marker.display_name = title; marker.kind = WorldAuthorNode.Kind.LANDMARK
		marker.coordinate_space = WorldAuthorNode.CoordinateSpace.CANVAS
		marker.position = Iso.project(origin+Vector2(640,500)); marker.landmark_kind = "gate"
		world.add_child(marker)
		var monster: UnitDefinition = load("res://features/units/data/monsters/%s.tres" % ["temple_hellhound","temple_double_hound","temple_lava_troll"][col])
		var count: int = 3 if col == 0 and row < 2 else 2
		var id: String = "BranchPatrol%d" % zone
		region(regions,id,title,monster,Rect2(origin+Vector2(160,200),Vector2(800,600)),count,3+row,LEVELS[row+1],"rainbow_forge")
		var area: WorldMonsterRegion = regions.get_node(id)
		area.simple_party = false
		var template := PartyTemplate.new(); template.template_id = "rainbow_mixed_%d" % zone
		template.display_name = ZONES[zone] + "混編"; template.representative = monster
		for member_id: String in [String(monster.id),"temple_lava_bat" if col != 0 else "rainbow_slime"]:
			var member := MemberRule.new()
			member.definition = load("res://features/units/data/monsters/%s.tres" % member_id)
			member.min_count = 2+row; member.max_count = member.min_count
			member.min_level = LEVELS[row+1]; member.max_level = member.min_level
			template.members.append(member)
		area.habitat.profile.templates.assign([template])
	world.definition = world.definition.duplicate(true)
	world.definition.extent = Vector2(5120,6400)
	world.set_meta("rainbow_branch_v3",true)
	save(settings,"res://features/rainbow/data/default_action.tres")
	pack(world,WORLD); world.free()
	print("RAINBOW_BRANCH_AUTHORED 12 thematic zones / 28 patrol parties / 8 deliberate boss encounters; balance calibration pending")
	quit()
