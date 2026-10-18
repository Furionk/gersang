class_name PuzzleImpact
extends RefCounted
# Presentation-only state. No gameplay RNG, timers, HP or input mutations.
const LIMIT: int = 48
var hits: Array[Dictionary] = []
var serial: int = 0
static func strength(combos: int) -> float:
	return 1.0+0.18*clampi(combos-1,0,9)
func record(event: Dictionary, element: int) -> void:
	if event.get("kind","") != "attack" or event.get("amount",0.0) <= 0: return
	var hit: Dictionary=event.duplicate()
	hit["age"]=0.0
	hit["element"]=element
	hit["strength"]=strength(event.get("combos",1))
	hit["serial"]=serial
	serial+=1
	if hits.size()>=LIMIT: hits.pop_front()
	hits.append(hit)
func advance(delta: float) -> void:
	for hit: Dictionary in hits: hit.age+=maxf(0,delta)
	hits=hits.filter(func(hit: Dictionary)->bool:return hit.age<0.85)
func flash(target: int) -> float:
	var value: float=0
	for hit: Dictionary in hits:
		if hit.target==target: value=maxf(value,clampf(1.0-hit.age/0.10,0,1))
	return value
func offset(target: int) -> Vector2:
	var result: Vector2=Vector2.ZERO
	for hit: Dictionary in hits:
		if hit.target==target and hit.age<0.20:
			var decay: float=1.0-hit.age/0.20
			result+=Vector2(cos(hit.age*95),sin(hit.age*77)*0.5)*3.0*hit.strength*decay
	return result.limit_length(10.0)
