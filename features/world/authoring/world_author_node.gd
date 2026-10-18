@tool
class_name WorldAuthorNode
extends Node2D
enum Kind { WALKABLE, BLOCKER, HABITAT, SAFE_AREA, PORTAL, ARRIVAL, LANDMARK, ROAD, SCENERY }
enum CoordinateSpace { LEGACY_LOGICAL, CANVAS }
@export var coordinate_space: CoordinateSpace = CoordinateSpace.LEGACY_LOGICAL
@export var kind: Kind = Kind.HABITAT
@export var stable_id: String = ""
@export var display_name: String = ""
@export var domain: PolygonDomain
@export var habitat: WorldHabitat
@export var target_map_id: String = ""
@export var target_entry_id: String = ""
@export var trigger_radius: float = 65
@export var facing: Vector2 = Vector2.DOWN
@export var landmark_kind: String = "town"
@export var road: PackedVector2Array = PackedVector2Array()
@export var layer_locked: bool = false
@export_group("Sprite / Hover")
@export var sprite_definition: WorldSceneryDefinition
var preview_view: WorldSceneryView
var preview_signature: String = ""
var editor_selected: bool = false

func _validate_property(property: Dictionary) -> void:
	if property.name in ["coordinate_space","layer_locked"]: property.usage &= ~PROPERTY_USAGE_EDITOR
	if property.name in ["target_map_id","target_entry_id","trigger_radius"] and kind!=Kind.PORTAL: property.usage &= ~PROPERTY_USAGE_EDITOR
	if property.name=="habitat" and kind!=Kind.HABITAT: property.usage &= ~PROPERTY_USAGE_EDITOR
	if property.name in ["domain","road"] and kind in [Kind.PORTAL,Kind.ARRIVAL,Kind.LANDMARK,Kind.SCENERY]: property.usage &= ~PROPERTY_USAGE_EDITOR

func set_editor_selected(value: bool) -> void:
	editor_selected = value
	queue_redraw()

func _draw() -> void:
	if not Engine.is_editor_hint() or not editor_selected:
		return
	if kind==Kind.PORTAL:
		var ring: PackedVector2Array = PackedVector2Array()
		var anchor: Vector2 = Vector2.ZERO if coordinate_space==CoordinateSpace.CANVAS else Iso.project(position)-position
		var basis: Transform2D = transform
		basis.origin = Vector2.ZERO
		var inverse_basis: Transform2D = basis.affine_inverse() if absf(basis.determinant())>0.000001 else Transform2D.IDENTITY
		for index: int in 49:
			ring.append(anchor+inverse_basis.basis_xform(Iso.project(Vector2.from_angle(TAU*index/48.0)*trigger_radius)))
		draw_polyline(ring,Color(0.3,1.0,0.5,0.9),2.0)
		draw_circle(anchor,4.0,Color(0.3,1.0,0.5))
		draw_string(ThemeDB.fallback_font,anchor+Vector2(10,18),"入口觸發範圍（內有可達地面即可）",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(0.5,1.0,0.6))
	var shape: PolygonDomain = habitat.activity_domain if kind == Kind.HABITAT and habitat != null else domain
	if shape != null and shape.outer.size() >= 3:
		var points: PackedVector2Array = PackedVector2Array()
		for point: Vector2 in shape.outer:
			points.append(Iso.project(point+position)-position)
		var color: Color = Color(0.5,0.8,0.2,0.16) if kind == Kind.HABITAT else Color(0.8,0.2,0.2,0.2) if kind == Kind.BLOCKER else Color(0.2,0.6,1,0.15)
		draw_colored_polygon(points,color)
		points.append(points[0])
		draw_polyline(points,color.lightened(0.4),2)
		for hole: PackedVector2Array in shape.holes:
			var contour: PackedVector2Array = PackedVector2Array()
			for point: Vector2 in hole:
				contour.append(Iso.project(point+position)-position)
			contour.append(contour[0])
			draw_polyline(contour,Color(1,0.5,0.2),2)
	elif sprite_definition==null:
		var at: Vector2 = Vector2.ZERO if coordinate_space==CoordinateSpace.CANVAS else Iso.project(position)-position
		draw_circle(at,6,Color(1,0.85,0.3))
		draw_string(ThemeDB.fallback_font,at+Vector2(12,-8),display_name if not display_name.is_empty() else stable_id,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color(1,0.9,0.6))

func sync_artwork() -> void:
	if sprite_definition==null: return
	var artwork: Sprite2D = get_node_or_null("Artwork") as Sprite2D
	if artwork==null: return
	var atlas: AtlasTexture = AtlasTexture.new()
	atlas.atlas = sprite_definition.texture
	atlas.region = sprite_definition.region()
	atlas.filter_clip = true
	artwork.texture = atlas
	artwork.centered = false
	artwork.transform = sprite_definition.artwork_transform()
	artwork.modulate = sprite_definition.tint

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		var signature: String = str(sprite_definition.get_instance_id())+str(sprite_definition.texture)+str(sprite_definition.atlas_region)+str(sprite_definition.sprite_scale)+str(sprite_definition.sprite_basis)+str(sprite_definition.foot_anchor)+str(sprite_definition.tint) if sprite_definition!=null else ""
		if signature!=preview_signature:
			preview_signature = signature
			if has_node("Artwork"):
				sync_artwork()
				return
			if is_instance_valid(preview_view):
				remove_child(preview_view)
				preview_view.queue_free()
			preview_view = null
			if sprite_definition!=null:
				preview_view = WorldSceneryView.new()
				preview_view.name = "EditorSceneryPreview"
				add_child(preview_view)
				preview_view.initialize(sprite_definition,position)
		if is_instance_valid(preview_view): preview_view.position = Vector2.ZERO if coordinate_space==CoordinateSpace.CANVAS else Iso.project(position)-position
