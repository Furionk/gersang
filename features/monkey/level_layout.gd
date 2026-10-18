@tool
class_name MonkeyLevelLayout
extends Node3D
## Authored gameplay markers; environment art remains owned by the imported scene.
@export var bounds: AABB = AABB(Vector3(-25,-8,-25),Vector3(50,40,50))
@export var water_height: float = -100.0
@export var intro_yaw: float = 0.0
@export var legacy_garden: bool = false
@export var activity_bounds: AABB = AABB(Vector3(-25,-8,-25),Vector3(50,40,50))

func spawn() -> Vector3:
	return get_node("PlayerSpawn").global_position

func intro_position() -> Vector3:
	var marker:=get_node_or_null("IntroCamera") as Node3D
	return marker.global_position if marker else spawn()+Vector3(0,1.4,0)

func home(kind: int) -> Vector3:
	return get_node("Monkeys/Monkey%d"%kind).global_position

func route(kind: int) -> Array[Vector3]:
	var points: Array[Vector3]=[]
	for marker: Node3D in get_node("Monkeys/Monkey%d"%kind).get_children(): points.append(marker.global_position)
	return points

func contains_point(at: Vector3) -> bool:
	return bounds.has_point(to_local(at))

func damage_at(at: Vector3) -> float:
	if not contains_point(at): return 10.0
	if legacy_garden and at.y < -1.6: return 20.0 if at.x>5 and at.z < -5 else 10.0
	if at.y<water_height: return 10.0
	return 0.0

func constrain(at: Vector3) -> Vector3:
	var p:=to_local(at)
	var area: AABB=bounds if legacy_garden else activity_bounds
	p.x=clampf(p.x,area.position.x+1,area.end.x-1)
	p.z=clampf(p.z,area.position.z+1,area.end.z-1)
	return to_global(p)
