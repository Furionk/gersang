extends SceneTree
var failures: int = 0
func _initialize() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
	print("PASS | " if value else "FAIL | ",title)
	if not value: failures+=1
func run() -> void:
	var cells: Dictionary = {}
	for y: int in 5:
		for x: int in 5: cells[Vector2i(x,y)] = true
	var rect: Array[PolygonDomain] = WorldTileGeometry.domains(cells,[],32)
	check(rect.size()==1 and rect[0].outer.size()==4,"merged rectangle")
	cells.erase(Vector2i(2,2))
	var hole: Array[PolygonDomain] = WorldTileGeometry.domains(cells,[],32)
	check(hole.size()==1 and hole[0].holes.size()==1 and not hole[0].contains(Vector2(80,80)),"native erased tile forms hole")
	check(hole[0].covers(PolygonDomain.rectangle(Rect2(5,5,45,20)).outer),"radius capsule can cross adjoining cells")
	var diagonal: Array[PolygonDomain] = WorldTileGeometry.domains({Vector2i.ZERO:true,Vector2i.ONE:true},[],32)
	check(diagonal.size()==2,"corner touching islands remain separate")
	var parts: Array[PackedVector2Array] = [PolygonDomain.rectangle(Rect2(32,0,13,32)).outer]
	var partial: Array[PolygonDomain] = WorldTileGeometry.domains({Vector2i.ZERO:true},parts,32)
	check(partial.size()==1 and partial[0].bounds()==Rect2(0,0,45,32),"exact partial boundary joins full cell")
	var set: TileSet = TileSet.new()
	set.tile_shape = TileSet.TILE_SHAPE_ISOMETRIC
	set.tile_layout = TileSet.TILE_LAYOUT_DIAMOND_DOWN
	set.tile_size = Vector2i(64,32)
	var layer: WorldTileLayer = WorldTileLayer.new()
	layer.tile_set = set
	layer.position = Vector2(-32,0)
	check(layer.logical_center(Vector2i.ZERO)==Vector2(16,16) and layer.logical_center(Vector2i(1,0))==Vector2(48,16),"native isometric cells match logical coordinates")
	layer.free()
	print("NATIVE_TILE_PREFLIGHT failures=",failures)
	quit(1 if failures else 0)
