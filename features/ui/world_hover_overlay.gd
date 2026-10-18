class_name WorldHoverOverlay
extends PanelContainer
var heading: Label
var description: Label
var prompt: Label
func _ready() -> void:
	name = "WorldEntranceTooltip"
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.015,0.02,0.016,0.78)
	style.border_color = Color(0.5,0.54,0.43,0.4)
	style.set_border_width_all(1)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	add_theme_stylebox_override("panel",style)
	var content: VBoxContainer = VBoxContainer.new()
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_theme_constant_override("separation",3)
	add_child(content)
	heading = Label.new()
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	heading.add_theme_color_override("font_color",Color(0.95,0.85,0.56))
	description = Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	prompt = Label.new()
	prompt.add_theme_color_override("font_color",Color(0.72,0.89,0.64))
	for label: Label in [heading,description,prompt]:
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		content.add_child(label)
	hide()

func present(view: WorldSceneryView, cursor: Vector2) -> void:
	var ui_scale: float = GameSettings.profile.ui_scale
	var width: float = minf(340*ui_scale,get_viewport().get_visible_rect().size.x-16)
	custom_minimum_size.x = width
	description.custom_minimum_size.x = width-20
	size.x = width
	for label: Label in [heading,description,prompt]: label.add_theme_font_size_override("font_size",int(14*ui_scale))
	if heading.text!=view.title or description.text!=view.definition.description:
		heading.text = view.title
		description.text = view.definition.description
		prompt.text = "左鍵點擊 · 走近入口進入"
		reset_size()
		call_deferred("_fit_content")
	show()
	follow_cursor(cursor)

func _fit_content() -> void:
	reset_size()
	follow_cursor(get_viewport().get_mouse_position())

func follow_cursor(cursor: Vector2) -> void:
	var bounds: Rect2 = get_viewport().get_visible_rect().grow(-8)
	var panel_size: Vector2 = get_combined_minimum_size().max(size)
	var at: Vector2 = cursor+Vector2(20,18)
	if at.x+panel_size.x>bounds.end.x: at.x = cursor.x-panel_size.x-18
	if at.y+panel_size.y>bounds.end.y: at.y = cursor.y-panel_size.y-18
	position = Vector2(clampf(at.x,bounds.position.x,maxf(bounds.position.x,bounds.end.x-panel_size.x)),clampf(at.y,bounds.position.y,maxf(bounds.position.y,bounds.end.y-panel_size.y)))
