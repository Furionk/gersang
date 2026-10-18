extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var path: String="res://features/world/data/river_bay.tscn"
	var original: String=FileAccess.get_file_as_string(path)
	if original.contains('name="MonkeyGardenRegion"'): push_error("Monkey region already exists"); quit(1); return
	var river: WorldMap2D=load(path).instantiate()
	var definition: WorldMapDefinition=river.compile_definition()
	var nav:=WorldNavigationService.new(); nav.register_map(definition)
	var center:=Vector2.ZERO
	for candidate: Vector2 in [Vector2(4600,2420),Vector2(4500,2420),Vector2(4800,2500),Vector2(4300,2400)]:
		var valid: bool=true
		for dx: int in [-65,0,65]:
			for dy: int in [-65,0,65]:
				var p: Vector2=candidate+Vector2(dx,dy)
				if not nav.segment_legal("river_bay","","PLAYER",p,p,16): valid=false
		if valid and nav.find_path("river_bay","","PLAYER",definition.entries.start.point,candidate,16).ok:
			center=candidate; break
	assert(center!=Vector2.ZERO,"No legal monkey region")
	var headers: String='[ext_resource type="Script" path="res://features/world/authoring/world_monster_region.gd" id="monkey_region_script"]\n[ext_resource type="Script" path="res://features/world/authoring/world_region_polygon.gd" id="monkey_polygon_script"]\n[ext_resource type="Resource" path="res://features/monkey/data/habitat.tres" id="monkey_habitat"]\n\n'
	var split: int=original.find("[sub_resource")
	assert(split>0); original=original.insert(split,headers)
	var addition: String='\n[node name="MonkeyGardenRegion" type="Node2D" parent="."]\nscript = ExtResource("monkey_region_script")\nstable_id = "monkey_garden_region"\ndisplay_name = "庭園猴子隊 · 3D捕猴"\nsimple_party = false\nparty_count = 1\nrespawn_min_seconds = 20.0\nrespawn_max_seconds = 20.0\nbattlefields = PackedStringArray("monkey_garden")\nhabitat = ExtResource("monkey_habitat")\n'
	for title: String in ["SpawnArea","RoamingArea","PursuitArea"]:
		var radius: float=40 if title=="SpawnArea" else 65
		var points:=PackedStringArray()
		for offset: Vector2 in [Vector2(-radius,-radius),Vector2(radius,-radius),Vector2(radius,radius),Vector2(-radius,radius)]:
			var p: Vector2=Iso.project(center+offset); points.append(str(p.x)); points.append(str(p.y))
		addition+='\n[node name="%s" type="Polygon2D" parent="MonkeyGardenRegion"]\nscript = ExtResource("monkey_polygon_script")\npolygon = PackedVector2Array(%s)\n'%[title,", ".join(points)]
	var f:=FileAccess.open(path,FileAccess.WRITE); f.store_string(original+addition); f.close(); river.free()
	print("MONKEY_REGION_OK center=",center); quit()
