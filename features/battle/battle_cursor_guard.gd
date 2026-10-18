class_name BattleCursorGuard
extends Node
## Session-wide visible confinement in world/countdown/battle; not FPS capture.
const PLAY_MODES: Array[StringName] = [&"world",&"countdown",&"battle"]
var director: GameDirector
var enabled: bool = false
var focused: bool = true
var confinement_active: bool = false
func _ready() -> void:
	focused = get_window().has_focus()
	get_window().focus_entered.connect(_focus_entered)
	get_window().focus_exited.connect(_focus_exited)
func _input(event: InputEvent) -> void:
	if director.mode in PLAY_MODES and event.is_action_pressed("toggle_cursor_lock") and not event.is_echo():
		if OS.has_feature("web"):
			director.message.emit("瀏覽器無法鎖定可見游標；請在遊戲畫面內操作。")
			get_viewport().set_input_as_handled(); return
		enabled = not enabled
		sync()
		director.message.emit("F1：游標%s" % ["鎖定於遊戲視窗" if enabled else "解鎖"])
		get_viewport().set_input_as_handled()
func _process(_delta: float) -> void: sync()
func sync() -> void:
	var desired: bool = enabled and director.mode in PLAY_MODES and focused and not director.hud.is_modal_open()
	if desired!=confinement_active:
		confinement_active = desired
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED if desired else Input.MOUSE_MODE_VISIBLE
func release(clear_preference: bool = true) -> void:
	if clear_preference: enabled = false
	confinement_active = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
func _focus_entered() -> void:
	focused = true
	sync()
func _focus_exited() -> void:
	focused = false
	sync()
func _exit_tree() -> void: release()
