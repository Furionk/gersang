class_name ClassicSkin
extends RefCounted
const ATLAS: Texture2D = preload("res://art/ui/classic/skin-v1.png")
static var cells: Dictionary = {}
static var extracted: Dictionary = {}
static func frame_texture(index: int) -> Texture2D:
	if extracted.has(index): return extracted[index]
	var cell: float = ATLAS.get_width()/4.0
	var rect: Rect2i = Rect2i(int(cell*0.06),int(cell*0.06),int(cell*0.90),int(cell*0.90)) if index==0 else Rect2i(int(cell*1.085),int(cell*0.075),int(cell*0.84),int(cell*0.84))
	var texture: ImageTexture = ImageTexture.create_from_image(ATLAS.get_image().get_region(rect))
	extracted[index] = texture
	return texture
static func icon(index: int) -> Texture2D:
	if cells.has(index):
		return cells[index]
	var cell: Vector2 = Vector2(ATLAS.get_width()/4.0,ATLAS.get_height()/4.0)
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = ATLAS
	atlas.region = Rect2(Vector2(index%4,index/4)*cell,cell)
	cells[index] = atlas
	return atlas
static func panel_style() -> StyleBoxTexture:
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = frame_texture(0)
	for side: Side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		box.set_texture_margin(side,12)
		box.set_content_margin(side,7)
	return box
static func button_style() -> StyleBoxTexture:
	var box: StyleBoxTexture = StyleBoxTexture.new()
	box.texture = frame_texture(1)
	for side: Side in [SIDE_LEFT,SIDE_TOP,SIDE_RIGHT,SIDE_BOTTOM]:
		box.set_texture_margin(side,7)
		box.set_content_margin(side,2)
	return box
static func inset_style() -> StyleBoxFlat:
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color(0.09,0.095,0.09,0.94)
	style.border_color = Color(0.61,0.58,0.47)
	style.set_border_width_all(1)
	return style
