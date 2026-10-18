extends RefCounted
## A time-expanded reachability search over public damage reservations.
## Call before publishing a new combination; never alter a published marker.
const STEP := 0.15
const DIRECTIONS := 8
var last_route: PackedVector2Array = PackedVector2Array()

func can_escape(start: Vector2, speed: float, radius: float, reservations: Array[Dictionary], legal_segment: Callable, start_delay: float = 0.0) -> bool:
	last_route.clear()
	if reservations.is_empty(): return true
	var horizon: float = 0
	for hazard: Dictionary in reservations:
		if not hazard.get("fired",false): horizon = maxf(horizon, float(hazard.warning) + 0.05)
	var frontier: Array[Dictionary] = [{"point":start,"route":PackedVector2Array([start])}]
	var time: float = 0
	while time < horizon:
		var next_time: float = minf(horizon, time + STEP)
		var distance: float = maxf(0, speed) * (maxf(0,next_time-start_delay) - maxf(0,time-start_delay))
		var next: Array[Dictionary] = []
		var visited: Dictionary = {}
		for entry: Dictionary in frontier:
			for index: int in DIRECTIONS + 1:
				var point: Vector2 = entry.point
				if index < DIRECTIONS: point += Vector2.from_angle(TAU * index / DIRECTIONS) * distance
				var key := Vector2i((point / 12).round())
				if visited.has(key): continue
				if not legal_segment.call(entry.point, point, radius): continue
				var safe: bool = true
				for hazard: Dictionary in reservations:
					if hazard.get("fired",false): continue
					var hit_time: float = hazard.warning
					if hit_time < time or hit_time > next_time: continue
					var moving_time: float = maxf(0,next_time-start_delay)-maxf(0,time-start_delay)
					var elapsed_moving: float = maxf(0,hit_time-start_delay)-maxf(0,time-start_delay)
					var at: Vector2 = Vector2(entry.point).lerp(point, clampf(elapsed_moving/maxf(0.001,moving_time),0,1))
					if RainbowTempleMechanics.contains(hazard, at, radius): safe = false; break
				if not safe: continue
				visited[key] = true
				var route: PackedVector2Array = entry.route.duplicate()
				route.append(point)
				var cost: float = point.distance_to(start) * 0.001
				for hazard: Dictionary in reservations:
					if hazard.get("fired",false) or float(hazard.warning) < next_time: continue
					if not RainbowTempleMechanics.contains(hazard,point,radius): continue
					var radial: float = point.distance_to(hazard.center)
					var escape: float = maxf(0,float(hazard.radius)+radius-radial)
					if hazard.kind == "ring": escape = minf(escape,maxf(0,radial-float(hazard.inner)+radius))
					cost += escape / maxf(0.1,float(hazard.warning)-next_time)
				next.append({"point":point,"route":route,"cost":cost})
		# A bounded search may reject a safe pattern; it never invents a safe route.
		if next.is_empty(): return false
		if next.size() > 24:
			next.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.cost < b.cost)
			next.resize(24)
		frontier = next
		time = next_time
	last_route = frontier[0].route
	return true
