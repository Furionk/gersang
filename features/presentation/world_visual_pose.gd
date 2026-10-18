class_name WorldVisualPose
extends RefCounted
# Presentation only. Never use interpolated positions for navigation/encounters.
var previous: Vector2 = Vector2.ZERO
var current: Vector2 = Vector2.ZERO
func reset(point: Vector2) -> void:
	previous = point
	current = point
func step(from: Vector2, to: Vector2) -> void:
	previous = from
	current = to
func sample(alpha: float) -> Vector2:
	return previous.lerp(current,clampf(alpha,0,1))
