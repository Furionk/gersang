class_name WorldMovementChecks
extends RefCounted

static func run(check: Callable, progress: Dictionary) -> Dictionary:
	var fixture: WorldMapDefinition = WorldMapDefinition.new()
	fixture.map_id = "movement_fixture"
	fixture.extent = Vector2(2048,2048)
	fixture.walkable = [PolygonDomain.rectangle(Rect2(Vector2.ZERO,fixture.extent))]
	var context: WorldContext = WorldContext.new()
	context.initialize(progress,3401,true,{fixture.map_id:fixture})
	context.ensure_map(fixture.map_id)
	context.state["player"]["map_id"] = fixture.map_id
	var from: Vector2 = Vector2(1040,1040)
	var to: Vector2 = from + Vector2(288,288)
	var started: int = Time.get_ticks_usec()
	var path: Dictionary = context.navigation.find_path(fixture.map_id,"","PLAYER",from,to,16)
	var query_us: int = Time.get_ticks_usec()-started
	var length: float = 0
	var lateral: float = 0
	var turns: int = 0
	var previous: Vector2 = Vector2.ZERO
	for i: int in range(1,path["points"].size()):
		var offset: Vector2 = path["points"][i]-path["points"][i-1]
		length += offset.length()
		lateral = maxf(lateral,absf(Iso.project(path["points"][i]-from).x))
		if offset.length_squared()>0.001:
			if previous != Vector2.ZERO and offset.normalized().dot(previous)<0.999: turns += 1
			previous = offset.normalized()
	check.call(path["ok"] and lateral < 0.05,"MOVE-01 screen-vertical route has no left/right staircase")
	check.call(absf(length-from.distance_to(to)) < 0.05 and turns == 0,"MOVE-02 unobstructed route is straight without grid heading changes")
	context.state["player"]["position"] = from
	context.move_player(to)
	var old: Vector2 = context.state["player"]["position"]
	context.tick(1.0/60.0)
	var world_speed: float = old.distance_to(context.state["player"]["position"])*60
	var battle_speed: float = context.state["player_party"]["deployed_units"][0]["resolved_stats"]["speed"]
	check.call(absf(world_speed-battle_speed)<0.01,"MOVE-03 world uses the same derived speed as battle")
	var metrics: Dictionary = {"vertical_lateral_units":lateral,"route_length":length,"direct_length":from.distance_to(to),"heading_changes":turns,"world_speed":world_speed,"battle_speed":battle_speed,"cold_query_us":query_us}
	for screen_direction: Vector2 in [Vector2.UP,Vector2.DOWN,Vector2.LEFT,Vector2.RIGHT,Vector2(-1,-1),Vector2(1,-1),Vector2(-1,1),Vector2(1,1)]:
		var destination: Vector2 = from+Iso.unproject(screen_direction.normalized()*192)
		context.state["player"]["position"] = from
		context.move_player(destination)
		var max_lateral: float = 0
		var total_length: float = 0
		var previous_point: Vector2 = from
		var step: int = 0
		while not context.player_path.is_empty() and step < 600:
			context.tick(1.0/60.0)
			var point: Vector2 = context.state["player"]["position"]
			var screen_offset: Vector2 = Iso.project(point-from)
			max_lateral = maxf(max_lateral,absf(screen_offset.cross(screen_direction.normalized())))
			total_length += previous_point.distance_to(point)
			previous_point = point
			step += 1
		check.call(max_lateral < 0.05,"MOVE-04 straight eight-direction trace " + str(screen_direction))
		check.call(absf(total_length-from.distance_to(destination))<0.05,"MOVE-05 no direction-dependent detour " + str(screen_direction))
	fixture.blockers = [PolygonDomain.rectangle(Rect2(1100,1100,160,160))]
	context.navigation.register_map(fixture)
	var detour: Dictionary = context.navigation.find_path(fixture.map_id,"","PLAYER",Vector2(1000,1000),Vector2(1400,1400),16)
	var legal: bool = detour["ok"]
	for i: int in range(1,detour["points"].size()):
		legal = legal and context.navigation.segment_legal(fixture.map_id,"","PLAYER",detour["points"][i-1],detour["points"][i],16)
	check.call(legal,"MOVE-06 route shortcuts never cut through blockers")
	var opposite: Vector2 = Vector2.DOWN
	for i: int in 30: opposite = MovementFeel.turn_facing(opposite,Vector2.UP,16)
	check.call(opposite.dot(Vector2.UP)>0.999,"MOVE-07 reversing direction cannot lock facing")
	check.call(MovementFeel.speed(130,1.5,0.5)==97.5,"MOVE-08 multiplier and timed slow use shared arithmetic")
	var pose: WorldVisualPose = WorldVisualPose.new()
	pose.step(Vector2(0,0),Vector2(0,4))
	check.call(pose.sample(0)==Vector2.ZERO and pose.sample(0.5)==Vector2(0,2) and pose.sample(1)==Vector2(0,4),"MOVE-09 intermediate render frame interpolates instead of freezing at a tick")
	pose.reset(Vector2(7000,3000))
	check.call(pose.sample(0.5)==Vector2(7000,3000),"MOVE-10 map changes reset interpolation without sliding across maps")
	fixture.blockers.clear()
	context.navigation.register_map(fixture)
	var positions: Array[Vector2] = []
	for fps: int in [30,60,120,144]:
		context.state["player"]["position"] = from
		context.move_player(from+Vector2(500,500))
		var accumulated: float = 0
		var camera: Vector2 = Vector2.ZERO
		for frame: int in fps*2:
			accumulated += 1.0/fps
			while accumulated+0.0000001 >= 1.0/60.0:
				context.tick(1.0/60.0)
				accumulated -= 1.0/60.0
			camera = camera.lerp(Vector2(0,100),MovementFeel.follow_alpha(1.0/fps))
		positions.append(context.state["player"]["position"])
		check.call(camera.distance_to(Vector2(0,100)*(1-exp(-10)))<0.01,"MOVE-11 camera response invariant at " + str(fps) + " FPS")
	for point: Vector2 in positions:
		check.call(point.distance_to(positions[0])<0.01,"MOVE-12 render rate cannot change authoritative movement")
	var steps: PackedVector2Array = PackedVector2Array([Vector2(10,0),Vector2(10,10),Vector2(20,10)])
	var moving: Dictionary = {"position":Vector2.ZERO,"facing":Vector2.RIGHT}
	WorldContext.advance_path(moving,steps,25)
	check.call(moving["position"].is_equal_approx(Vector2(15,10)),"MOVE-13 crossing waypoints never discards remaining travel distance")
	return metrics
