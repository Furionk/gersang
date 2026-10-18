@tool
class_name WorldSceneryDefinition
extends Resource
## Visual only: walkable/obstacle TileMap masks remain navigation authority.
@export var display_name: String = "地景"
@export_multiline var description: String = ""
@export var texture: Texture2D
@export var atlas_region: Rect2 = Rect2()
@export var foot_anchor: Vector2 = Vector2(256,480)
@export_range(0.05,3.0,0.01) var sprite_scale: float = 0.45
@export var sprite_basis: Transform2D = Transform2D.IDENTITY
@export var tint: Color = Color.WHITE
@export_group("深度排序")
## 貼地永遠在角色下方；立體與角色按腳底Y交錯；前景永遠覆蓋角色。同款素材共享這個預設。
@export_enum("貼地裝飾", "立體自動排序", "固定前景") var sorting_mode: int = 1:
	set(value):
		if sorting_mode==value: return
		sorting_mode=value
		emit_changed()
## 多棵樹／地面與山牆同圖時，一個脚底不能描述全部深度。保留原圖，另作分件審閱。
@export var sorting_review_required: bool = false
## 分類依據或待分件原因；只供Artist審閱，不改障礙或自動猜測PNG內容。
@export_multiline var sorting_note: String = ""
@export_group("輪廓提示")
@export_range(0.01,0.9,0.01) var alpha_threshold: float = 0.18
@export var outline_color: Color = Color(0.25,1.0,0.10,1.0)
@export_range(1.0,8.0,0.5) var outline_pixels: float = 3.0

func region() -> Rect2:
	return atlas_region if atlas_region.has_area() else Rect2(Vector2.ZERO,texture.get_size()) if texture!=null else Rect2()

func artwork_transform() -> Transform2D:
	# Calibrate pre-rendered art without changing author positions or planar navigation.
	var value: Transform2D = Transform2D(sprite_basis.x * sprite_scale, sprite_basis.y * sprite_scale, Vector2.ZERO)
	value.origin = -(value.basis_xform(foot_anchor))
	return value
