@tool
class_name MovementFeel
extends RefCounted
# MOVE-03/07: shared arithmetic; world must not invent its own speed/turn rate.
static func speed(derived_speed: float, multiplier: float, status_multiplier: float = 1.0) -> float:
	return derived_speed * multiplier * status_multiplier

static func turn_facing(previous: Vector2, direction: Vector2, turn_speed: float, delta: float = 1.0/60.0) -> Vector2:
	if direction.length_squared() < 0.001:
		return previous
	var alpha: float = minf(1.0,turn_speed*delta)
	if previous.length_squared() > 0.001 and previous.normalized().dot(direction.normalized()) < -0.9999:
		# Normalizing a linear blend of opposite vectors otherwise locks facing forever.
		return previous.normalized().rotated(PI*alpha)
	var blended: Vector2 = previous.lerp(direction.normalized(),alpha)
	return blended.normalized() if blended.length_squared() > 0.001 else direction.normalized()

static func follow_alpha(delta: float, response: float = 5.0) -> float:
	return 1.0-exp(-response*maxf(0,delta))
