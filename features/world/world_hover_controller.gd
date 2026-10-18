class_name WorldHoverController
extends Node
var director: GameDirector
var overlay: WorldHoverOverlay
var selected: WorldSceneryView
func initialize(game: GameDirector) -> void:
	director = game
	overlay = WorldHoverOverlay.new()
	game.hud.root.add_child(overlay)

func pick(world_point: Vector2) -> WorldSceneryView:
	if director.ground==null: return null
	var best: WorldSceneryView
	for view: WorldSceneryView in director.ground.scenery_views:
		if is_instance_valid(view) and not view.portal_id.is_empty() and view.hit_test(world_point):
			if best==null or view.global_position.y>=best.global_position.y: best=view
	return best

func clear() -> void:
	if is_instance_valid(selected): selected.set_highlight(false)
	selected = null
	if is_instance_valid(overlay): overlay.hide()
	Input.set_default_cursor_shape(Input.CURSOR_ARROW)

func update_hover(cursor: Vector2, over_gui: bool = false) -> void:
	if director.mode!=&"world" or director.hud.is_modal_open() or over_gui:
		clear()
		return
	var world: Vector2 = director.get_canvas_transform().affine_inverse()*cursor
	var target: WorldSceneryView = pick(world)
	if target!=selected:
		if is_instance_valid(selected): selected.set_highlight(false)
		selected = target
		if target!=null:
			target.set_highlight(true)
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		else: clear()
	if is_instance_valid(selected): overlay.present(selected,cursor)

func _process(_delta: float) -> void:
	var gui: Control = get_viewport().gui_get_hovered_control()
	update_hover(get_viewport().get_mouse_position(),gui!=null)

func _exit_tree() -> void: clear()
