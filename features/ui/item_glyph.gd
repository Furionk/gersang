class_name ItemGlyph
extends Control
var item_id: StringName = &""
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _draw() -> void:
	var at: Vector2 = size * 0.5
	var definition: GearItemDefinition = ItemCatalog.get_item(item_id)
	if definition != null and definition.icon != null:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var dimensions: Vector2 = definition.icon.get_size()
		var factor: float = minf((size.x-8)/dimensions.x,(size.y-8)/dimensions.y)
		var drawn: Vector2 = dimensions*factor
		draw_texture_rect(definition.icon,Rect2(at-drawn*0.5,drawn),false)
		return
	var gold: Color = Color(0.92, 0.74, 0.35)
	match item_id:
		&"blade":
			draw_line(at + Vector2(-13, 12), at + Vector2(14, -15), Color(0.82, 0.89, 0.88), 5)
			draw_line(at + Vector2(-12, 1), at + Vector2(0, 13), gold, 4)
			draw_line(at + Vector2(-18, 18), at + Vector2(-8, 8), Color(0.52, 0.22, 0.13), 5)
		&"coat":
			draw_colored_polygon(PackedVector2Array([at+Vector2(-12,-15),at+Vector2(-24,-3),at+Vector2(-14,3),at+Vector2(-13,18),at+Vector2(13,18),at+Vector2(14,3),at+Vector2(24,-3),at+Vector2(12,-15)]), Color(0.44,0.22,0.13))
			draw_line(at+Vector2(0,-15),at+Vector2(0,17),gold,3)
		&"hat":
			draw_circle(at,15,Color(0.28,0.41,0.50))
			draw_line(at+Vector2(-22,7),at+Vector2(22,7),gold,5)
			draw_line(at+Vector2(0,-13),at+Vector2(0,2),gold,3)
		&"charm":
			draw_arc(at,17,0,TAU,32,gold,3)
			draw_circle(at,10,Color(0.27,0.64,0.51))
		&"food":
			draw_circle(at,18,Color(0.89,0.85,0.70))
			draw_rect(Rect2(at+Vector2(-8,1),Vector2(16,15)),Color(0.15,0.23,0.17))
		&"tea":
			draw_style_box(_cup(),Rect2(at+Vector2(-18,-7),Vector2(36,26)))
			draw_line(at+Vector2(-7,-19),at+Vector2(-4,-11),gold,2)
			draw_line(at+Vector2(5,-22),at+Vector2(7,-12),gold,2)
		&"material":
			draw_colored_polygon(PackedVector2Array([at+Vector2(-17,8),at+Vector2(-10,-13),at+Vector2(9,-17),at+Vector2(19,4),at+Vector2(6,17)]),Color(0.49,0.44,0.32))
var cup_style: StyleBoxFlat
func _cup() -> StyleBoxFlat:
	if cup_style == null:
		cup_style = StyleBoxFlat.new()
		cup_style.bg_color = Color(0.30,0.55,0.43)
		cup_style.border_color = Color(0.92,0.74,0.35)
		cup_style.set_border_width_all(2)
	return cup_style
