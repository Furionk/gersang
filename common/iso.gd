class_name Iso
extends RefCounted
const CELL: float = 40.0
const CIRCLE_SCALE: Vector2 = Vector2(1.414213562, 0.707106781)
static func project(p: Vector2) -> Vector2:
	return Vector2(p.x - p.y, (p.x + p.y) * 0.5)
static func unproject(p: Vector2) -> Vector2:
	return Vector2(p.x * 0.5 + p.y, p.y - p.x * 0.5)
static func direction_index(facing: Vector2) -> int:
	return posmod(int(round(project(facing).angle() / (PI / 4.0))), 8)
