extends Panel
func _draw() -> void:
	var gold: Color = Color(0.58,0.47,0.29)
	draw_rect(Rect2(Vector2(5,5),size-Vector2(10,10)),gold,false,1)
	for corner: Vector2 in [Vector2(10,10),Vector2(size.x-10,10),Vector2(10,size.y-10),size-Vector2(10,10)]:
		var x: float = 1 if corner.x < size.x*0.5 else -1
		var y: float = 1 if corner.y < size.y*0.5 else -1
		draw_polyline(PackedVector2Array([corner+Vector2(0,y*20),corner,corner+Vector2(x*20,0)]),gold,2)
		draw_colored_polygon(PackedVector2Array([corner+Vector2(x*4,y*4),corner+Vector2(x*13,y*7),corner+Vector2(x*7,y*13)]),gold)
	draw_line(Vector2(18,48),Vector2(size.x-18,48),gold,1)
