class_name VictoryScroll
extends Control
@export var title: String = "勝利"
## Native parchment/wood presentation, not a new raster asset or gameplay clock.
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var face: Font = load("res://art/fonts/NotoSansCJKtc-Regular.otf")
	var caption: Label = Label.new()
	caption.text = title
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.add_theme_font_override("font",face)
	caption.add_theme_font_size_override("font_size",64)
	caption.add_theme_color_override("font_color",Color(0.06,0.055,0.035))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(caption)
func _draw() -> void:
	var paper: Rect2 = Rect2(Vector2(13,5),size-Vector2(26,10))
	draw_rect(paper,Color("cfc9b5"))
	draw_rect(paper,Color("67604e"),false,3)
	for i: int in 90:
		var at: Vector2 = Vector2(19+posmod(i*71,int(size.x-38)),10+posmod(i*37,int(size.y-20)))
		draw_line(at,at+Vector2(4,0),Color(0.31,0.29,0.24,0.09),1)
	for x: float in [0.0,size.x-14]:
		draw_rect(Rect2(x,0,14,size.y),Color("4d322a"))
		draw_rect(Rect2(x+3,2,3,size.y-4),Color("8c6150"))
		draw_rect(Rect2(x,0,14,size.y),Color("201b17"),false,2)
