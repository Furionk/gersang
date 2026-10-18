@tool
class_name WorldSceneryView
extends Node2D
const OUTLINE: Shader = preload("res://features/world/scenery_outline.gdshader")
static var shared_materials: Dictionary = {}
static var masks: Dictionary = {}
var definition: WorldSceneryDefinition
var portal_id: String = ""
var logical_point: Vector2
var title: String = ""
var sprite: Sprite2D
var mask: BitMap
var highlighted: bool = false

func initialize(data: WorldSceneryDefinition, point: Vector2, portal: String = "", label: String = "") -> void:
	definition = data
	ScenerySorting.apply_item(self,data.sorting_mode)
	logical_point = point
	portal_id = portal
	title = label if not label.is_empty() else data.display_name
	if data.texture==null: return
	var region: Rect2 = data.region()
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = data.texture
	atlas.region = region
	atlas.filter_clip = true
	sprite = Sprite2D.new()
	sprite.name = "ScenerySprite"
	sprite.texture = atlas
	sprite.centered = false
	sprite.transform = data.artwork_transform()
	sprite.modulate = data.tint
	var size: Vector2 = data.texture.get_size()
	var material_key: String = "%s:%s:%s:%s:%s" % [data.texture.get_rid(),region,data.alpha_threshold,data.outline_color,data.outline_pixels]
	if not shared_materials.has(material_key):
		var material: ShaderMaterial = ShaderMaterial.new()
		material.shader = OUTLINE
		material.set_shader_parameter("atlas_bounds",Vector4(region.position.x/size.x,region.position.y/size.y,region.end.x/size.x,region.end.y/size.y))
		material.set_shader_parameter("alpha_threshold",data.alpha_threshold)
		material.set_shader_parameter("outline_color",data.outline_color)
		material.set_shader_parameter("outline_width",data.outline_pixels)
		shared_materials[material_key] = material
	# Share decor; isolate only the few portals whose hover state can differ.
	sprite.material = shared_materials[material_key] if portal.is_empty() else shared_materials[material_key].duplicate()
	add_child(sprite)
	# Cache immutable CPU opacity, never read GPU images while hovering.
	if not Engine.is_editor_hint() and not portal_id.is_empty():
		var key: String = "%s:%s:%s" % [data.texture.get_rid(),region,data.alpha_threshold]
		if not masks.has(key):
			var bitmap: BitMap = BitMap.new()
			bitmap.create_from_image_alpha(atlas.get_image(),data.alpha_threshold)
			masks[key] = bitmap
		mask = masks[key]

func hit_test(world_point: Vector2) -> bool:
	if sprite==null or mask==null or not is_visible_in_tree(): return false
	var local: Vector2 = sprite.to_local(world_point)
	var pixel: Vector2i = Vector2i(local.floor())
	return Rect2(Vector2.ZERO,sprite.texture.get_size()).has_point(local) and mask.get_bitv(pixel)

func set_highlight(value: bool) -> void:
	if highlighted==value: return
	highlighted = value
	if sprite!=null: (sprite.material as ShaderMaterial).set_shader_parameter("highlighted",1.0 if value else 0.0)
