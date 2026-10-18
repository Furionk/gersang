@tool
class_name BattleSpawnZone
extends Marker2D
enum Teams { BOTH, ALLIES, ENEMIES }
## 主位置允許Both雙方、Allies我方或Enemies敵方。
@export var allowed_teams: Teams = Teams.BOTH
## 效果或區域的邏輯半徑（世界單位）；等角畫面會呈現為橢圓。
@export_range(40,600,10) var radius: float = 220:
	set(value): radius=value; queue_redraw()
## 此出生區允許的整批人數上限；必須有足夠合法、不重疊的落腳點。
@export_range(1,60) var capacity: int = 60
func _draw() -> void:
	if not Engine.is_editor_hint(): return
	var points: PackedVector2Array = PackedVector2Array()
	for i: int in 49: points.append(Iso.project(Vector2.from_angle(TAU*i/48.0)*radius))
	draw_polyline(points,Color(1,0.8,0.25,0.7),2)
	draw_string(ThemeDB.fallback_font,Vector2(12,-12),str(name)+" · "+str(capacity)+"人",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(1,0.9,0.5))
