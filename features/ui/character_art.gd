class_name CharacterArt
extends RefCounted
const SHEET: Texture2D = preload("res://art/ui/classic/characters-v1.png")
# Authored face anchors in the independent illustration sheet, never battle sprites.
const EYES: Array[Vector2] = [Vector2(0.55,0.12),Vector2(0.53,0.135),Vector2(0.49,0.15),Vector2(0.45,0.175),Vector2(0.47,0.135),Vector2(0.445,0.14),Vector2(0.49,0.16)]
static var cache: Dictionary = {}
static func texture(data: UnitDefinition, view: String = "standee") -> Texture2D:
	if view=="eyes" and data.eyes_texture!=null: return data.eyes_texture
	var authored: Texture2D=data.standee_texture if view=="standee" else data.portrait_texture
	if authored!=null: return authored
	var path: String = data.standee_path if view == "standee" else data.portrait_path
	if path != "":
		return load(path) as Texture2D
	var index: int = clampi(data.illustration_index,0,6)
	var key: String = "%d:%s" % [index,view]
	if cache.has(key):
		return cache[key]
	var cell: Vector2 = Vector2(SHEET.get_width()/4.0,SHEET.get_height()/2.0)
	var origin: Vector2 = Vector2(index%4,index/4)*cell
	var rect: Rect2 = Rect2(origin,cell)
	if view != "standee":
		var center: Vector2 = origin + EYES[index]*cell
		var extent: Vector2 = Vector2(cell.x*0.44,cell.y*0.077) if view == "eyes" else Vector2(cell.x*0.44,cell.x*0.44)
		rect = Rect2(center-extent*0.5,extent)
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = rect
	cache[key] = atlas
	return atlas
