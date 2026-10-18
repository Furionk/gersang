@tool
class_name BattlefieldCompiler
extends RefCounted
static func compile(root: Node) -> Dictionary:
	var errors: Array[String] = []
	var cells: Vector2i = root.get("battlefield_cells")
	var walkable: Dictionary = {}
	var solid: Dictionary = {}
	var zones: Array[Dictionary] = []
	var ground: TileMapLayer
	if cells.x<1 or cells.y<1: errors.append("戰場格數必須大於0")
	if root is Node2D and not root.transform.is_equal_approx(Transform2D.IDENTITY): errors.append("戰場根保持原點、比例1、旋轉0")
	for node: Node in WorldAuthorTree.nodes(root):
		if node is BattleTileLayer:
			if node.tile_set==null or node.tile_set.tile_shape!=TileSet.TILE_SHAPE_ISOMETRIC or node.tile_set.tile_layout!=TileSet.TILE_LAYOUT_DIAMOND_DOWN or node.tile_set.tile_size!=Vector2i(80,40) or not WorldAuthorTree.canvas_transform(node,root).is_equal_approx(Transform2D(0,Vector2(-40,0))):
				errors.append(str(node.name)+"：使用80×40等角格，位置(-40,0)，比例1、旋轉0")
				continue
			if node.role==BattleTileLayer.Role.GROUND: ground=node
			for cell: Vector2i in node.get_used_cells():
				if not Rect2i(Vector2i.ZERO,cells).has_point(cell): errors.append(str(node.name)+"：格子超出 Battlefield Cells："+str(cell)); continue
				if node.role==BattleTileLayer.Role.WALKABLE: walkable[cell]=true
				elif node.role==BattleTileLayer.Role.BLOCKERS: solid[cell]=true
		elif node is BattleSpawnZone:
			var point: Vector2 = Iso.unproject(WorldAuthorTree.canvas_transform(node,root).origin)
			if not point.is_finite() or not is_finite(node.radius) or node.radius<=0 or node.capacity<1 or node.capacity>60:
				errors.append(str(node.name)+"：出生位置／半徑／容量無效")
				continue
			if not is_zero_approx(node.rotation) or not node.scale.is_equal_approx(Vector2.ONE): errors.append(str(node.name)+"：出生區用 Radius 調大小，不縮放 Marker")
			zones.append({"id":str(root.get_path_to(node)),"point":point,"radius":node.radius,"capacity":node.capacity,"teams":node.allowed_teams})
	if ground==null or ground.get_used_cells().is_empty(): errors.append("Ground 至少鋪一格")
	if walkable.is_empty(): errors.append("Walkable 必須畫可行格")
	if zones.size()<5: errors.append("至少保留5個 SpawnZone 主位置")
	if not zones.any(func(zone: Dictionary) -> bool: return zone.teams in [BattleSpawnZone.Teams.BOTH,BattleSpawnZone.Teams.ALLIES]): errors.append("SpawnZones 缺少可給我方的主位置")
	if not zones.any(func(zone: Dictionary) -> bool: return zone.teams in [BattleSpawnZone.Teams.BOTH,BattleSpawnZone.Teams.ENEMIES]): errors.append("SpawnZones 缺少可給敵方的主位置")
	var blocked: Array[Rect2i] = []
	for x: int in cells.x:
		for y: int in cells.y:
			var cell: Vector2i = Vector2i(x,y)
			if not walkable.has(cell) or solid.has(cell): blocked.append(Rect2i(cell,Vector2i.ONE))
	var clear_cells: Dictionary = {}
	for cell: Vector2i in walkable:
		var clear: bool = true
		for dx: int in range(-1,2):
			for dy: int in range(-1,2):
				var neighbor: Vector2i = cell+Vector2i(dx,dy)
				if not walkable.has(neighbor) or solid.has(neighbor): clear=false
		if clear: clear_cells[cell]=true
	var components: Dictionary = {}
	var component_id: int = 0
	for cell: Vector2i in clear_cells:
		if components.has(cell): continue
		var queue: Array[Vector2i] = [cell]; components[cell]=component_id
		var cursor: int = 0
		while cursor<queue.size():
			var current: Vector2i = queue[cursor]; cursor+=1
			for offset: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
				var next: Vector2i = current+offset
				if clear_cells.has(next) and not components.has(next): components[next]=component_id; queue.append(next)
		component_id+=1
	var common_component: int = -1
	for zone: Dictionary in zones:
		var available: int = 0
		var zone_component: int = -1
		for cell: Vector2i in clear_cells:
			if ((Vector2(cell)+Vector2.ONE*0.5)*Iso.CELL).distance_to(zone.point)>zone.radius: continue
			available+=1
			if zone_component==-1: zone_component=components[cell]
			elif zone_component!=components[cell]: errors.append(zone.id+"：出生圈跨越不連通區域，請調整位置或障礙"); break
		if available<zone.capacity: errors.append(zone.id+"：區內合法出生格 "+str(available)+" 少於容量 "+str(zone.capacity))
		if common_component==-1: common_component=zone_component
		elif zone_component!=common_component: errors.append(zone.id+"：不能走到其他出生主位置，請留通路")
	return {"errors":errors,"cells":cells,"walkable":walkable,"blocked":blocked,"zones":zones,"ground":ground}

static func deployment(ground: GroundMap, zones: Array[Dictionary], groups: Array[Dictionary], random: RandomNumberGenerator, clearance: float = 26.0) -> Dictionary:
	var order: Array[Dictionary] = zones.duplicate(true)
	for i: int in range(order.size()-1,0,-1):
		var j: int = random.randi_range(0,i)
		var tmp: Dictionary = order[i]; order[i]=order[j]; order[j]=tmp
	var candidates: Array[Array] = []
	for group: Dictionary in groups:
		var choices: Array[Dictionary] = []
		for zone: Dictionary in order:
			if zone.capacity<int(group.count) or (zone.teams!=BattleSpawnZone.Teams.BOTH and zone.teams!=(BattleSpawnZone.Teams.ALLIES if group.team==0 else BattleSpawnZone.Teams.ENEMIES)): continue
			var points: Array[Vector2] = []
			for x: int in ground.cells.x:
				for y: int in ground.cells.y:
					var cell: Vector2i = Vector2i(x,y)
					var point: Vector2 = (Vector2(cell)+Vector2.ONE*0.5)*Iso.CELL
					if not ground._navigation_blocked(cell) and point.distance_to(zone.point)<=float(zone.radius): points.append(point)
			points.sort_custom(func(a: Vector2,b: Vector2) -> bool: return a.distance_squared_to(zone.point)<b.distance_squared_to(zone.point))
			if clearance>Iso.CELL:
				var spaced: Array[Vector2] = []
				for point: Vector2 in points:
					if spaced.any(func(other: Vector2) -> bool: return other.distance_squared_to(point)<clearance*clearance): continue
					spaced.append(point)
				points=spaced
			if points.size()>=int(group.count): choices.append({"id":zone.id,"center":zone.point,"points":points.slice(0,int(group.count))})
		candidates.append(choices)
	var result: Array[Dictionary] = []
	if not assign(candidates,0,{}, {},result,clearance): return {"ok":false,"error":"出生主位置不足／重疊，請調整 SpawnZones 容量、半徑或隊伍類別。"}
	return {"ok":true,"groups":result}
static func assign(candidates: Array[Array], index: int, used: Dictionary, occupied: Dictionary, result: Array[Dictionary], clearance: float) -> bool:
	if index==candidates.size(): return true
	for choice: Dictionary in candidates[index]:
		if used.has(choice.id): continue
		var overlap: bool = false
		for point: Vector2 in choice.points:
			if occupied.has(point): overlap=true; break
			if clearance>Iso.CELL and occupied.keys().any(func(other: Vector2) -> bool: return other.distance_squared_to(point)<clearance*clearance): overlap=true; break
		if overlap: continue
		used[choice.id]=true
		for point: Vector2 in choice.points: occupied[point]=true
		result.append(choice)
		if assign(candidates,index+1,used,occupied,result,clearance): return true
		result.pop_back(); used.erase(choice.id)
		for point: Vector2 in choice.points: occupied.erase(point)
	return false
