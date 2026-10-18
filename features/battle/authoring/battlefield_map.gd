@tool
class_name BattlefieldMap
extends Node2D
## 穩定Arena ID，怪區Battlefields以此選擇戰場。
@export var arena_id: String = "meadow"
## 戰場邏輯格數，非畫面尺寸；擴大後需自行鋪地與通行格。
@export var battlefield_cells: Vector2i = Vector2i(44,38)
func _ready() -> void:
	ScenerySorting.apply_map(self)
	if not Engine.is_editor_hint() and get_parent()==get_tree().root:
		call_deferred("preview")
func preview() -> void:
	var compiled: Dictionary = BattlefieldCompiler.compile(self)
	if not compiled.errors.is_empty(): push_error("戰場無效：\n"+"\n".join(compiled.errors)); return
	WorldCatalog.initialize()
	if not WorldCatalog.arenas.has(arena_id): push_error("戰場 ID 未登錄："+arena_id); return
	for child: Node in get_children():
		if child is CanvasItem: child.hide()
	var game: Node = load("res://main.tscn").instantiate()
	add_child(game)
	while game.get("mode")!=&"world": await get_tree().process_frame
	game.call("start_battle",WorldCatalog.arenas[arena_id].encounter,"--stress-battlefield-preview" in OS.get_cmdline_user_args())
	var deadline: int = Time.get_ticks_msec()+10000
	while game.get("mode")!=&"battle" and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	if game.get("mode")!=&"battle": push_error("戰場試玩未能入場，請檢查出生區容量與可用隊伍類型。"); return
	var session: Node = get_tree().root.get_node("WorldSession")
	var progress: Node = get_tree().root.get_node("PartyProgress")
	print("BATTLEFIELD_F6_READY arena=",arena_id," world_save_enabled=",session.get("context").save.enabled," party_save_enabled=",progress.get("persistence_enabled"))
	if "--capture-battlefield-preview" in OS.get_cmdline_user_args():
		game.set_physics_process(false)
		game.get("camera").position=Iso.project(Vector2(battlefield_cells)*Iso.CELL*0.5)
		game.get("camera").zoom=Vector2.ONE*0.45
		if DisplayServer.get_name()!="headless":
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://artifacts/battlefield-scenes-2026-10-11/preview-%s.png" % arena_id)
		get_tree().quit()
