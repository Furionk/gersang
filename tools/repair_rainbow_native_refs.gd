extends "res://tools/expand_rainbow_dungeon.gd"
func run() -> void:
	var world: WorldMap2D = load(WORLD).instantiate()
	if world.has_meta("rainbow_external_refs_v1"): world.free(); quit(1); return
	var area: WorldMonsterRegion = world.get_node("MonsterRegions/SlimeCourt")
	area.monster = load("res://features/units/data/monsters/rainbow_slime.tres")
	area.display_name = "熔岩前庭 · 熔岩史萊姆"
	world.set_meta("rainbow_external_refs_v1",true); pack(world,WORLD); world.free()
	print("RAINBOW_REFERENCE_REPAIR stable external slime definition retained")
	quit()
