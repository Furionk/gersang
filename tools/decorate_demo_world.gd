extends SceneTree
func _initialize() -> void:
	call_deferred("decorate")
func decorate() -> void:
	var files: Array[String] = ["river_bay","qingling_town"]
	for id: String in files:
		var path: String = "res://features/world/data/%s.tscn" % id
		var scene: PackedScene = load(path) as PackedScene
		var map: WorldMap2D = scene.instantiate() as WorldMap2D
		if map.has_meta("decor_v1"):
			map.free()
			continue
		var specs: Array = [["forest",Rect2(2500,420,480,160)],["forest",Rect2(3350,550,380,220)],["forest",Rect2(2050,1250,180,500)],["forest",Rect2(350,800,160,280)],["building",Rect2(4380,1200,280,300)],["building",Rect2(5380,1200,280,300)],["water",Rect2(5850,0,294,4096)],["rock",Rect2(40,2650,400,1446)]] if id == "river_bay" else [["building",Rect2(160,160,240,220)],["building",Rect2(1050,170,260,280)],["building",Rect2(1100,630,240,220)]]
		for i: int in specs.size():
			var node: WorldAuthorNode = WorldAuthorNode.new()
			node.name = "Landcover_%d" % i
			node.stable_id = "landcover_%s_%d" % [id,i]
			node.kind = WorldAuthorNode.Kind.BLOCKER
			node.domain = PolygonDomain.rectangle(specs[i][1])
			node.domain.visual_kind = specs[i][0]
			map.add_child(node)
			node.owner = map
		map.set_meta("decor_v1",true)
		var packed: PackedScene = PackedScene.new()
		var error: Error = packed.pack(map)
		if error == OK: error = ResourceSaver.save(packed,path)
		print("DECORATE_MAP ",id," ",error)
		map.free()
	quit()
