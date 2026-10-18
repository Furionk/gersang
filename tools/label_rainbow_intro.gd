extends "res://tools/expand_rainbow_dungeon.gd"
func run() -> void:
	var world: WorldMap2D = load(WORLD).instantiate()
	if world.has_meta("rainbow_intro_labels_v3"): quit(1); return
	var labels: Dictionary = {"court_sign":"熔岩前庭 · 建議 Lv25 · 自由深入","nest_sign":"獵獸裂谷 · 建議 Lv25 · 自由深入","priest_sign":"祭火門庭 · 單祭司 · 建議 Lv25","dragon_sign":"簡單火龍 · 建議 Lv25 · 學習挑戰"}
	for child: Node in world.get_children():
		if child is WorldAuthorNode and labels.has(child.stable_id): child.display_name = labels[child.stable_id]
	world.set_meta("rainbow_intro_labels_v3",true)
	pack(world,WORLD); world.free(); quit()
