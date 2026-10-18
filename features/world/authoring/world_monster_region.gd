@tool
class_name WorldMonsterRegion
extends WorldAuthorNode
## Common author choices are flat. Mixed parties retain their original profile.
enum ShapeSource { TILE_BRUSH, POLYGON }
@export_category("怪物與隊伍")
@export var simple_party: bool = true:
	set(value):
		simple_party = value
		notify_property_list_changed()
@export var monster: UnitDefinition
@export_range(1,60) var minimum_units: int = 3
@export_range(1,60) var maximum_units: int = 5
@export_range(1,100) var minimum_level: int = 1
@export_range(1,100) var maximum_level: int = 5
@export_category("數量與重生")
@export_range(0,100) var party_count: int = 6
@export_range(0,3600,0.1) var respawn_min_seconds: float = 15
@export_range(0,3600,0.1) var respawn_max_seconds: float = 25
@export var aggressive: bool = false
@export_category("戰場")
@export var battlefields: PackedStringArray = PackedStringArray(["meadow"])
@export_group("04 Shape / 原生範圍工具")
@export var shape_source: ShapeSource = ShapeSource.POLYGON

func _init() -> void:
	kind = Kind.HABITAT
	coordinate_space = CoordinateSpace.CANVAS

func _draw() -> void:
	if not Engine.is_editor_hint() or not editor_selected: return
	draw_string(ThemeDB.fallback_font,Vector2(12,-12),"%s · %d隊 · Lv.%d–%d" % [display_name,party_count,minimum_level,maximum_level],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color(1,0.9,0.6))

func _validate_property(property: Dictionary) -> void:
	if property.name=="habitat" and simple_party: property.usage &= ~PROPERTY_USAGE_EDITOR
	if property.name in ["monster","minimum_units","maximum_units","minimum_level","maximum_level"] and not simple_party: property.usage &= ~PROPERTY_USAGE_EDITOR
	if property.name in ["kind","domain","target_map_id","target_entry_id","trigger_radius","facing","landmark_kind","road","layer_locked","sprite_definition","coordinate_space"]:
		property.usage &= ~PROPERTY_USAGE_EDITOR

func compile_habitat(root: Node) -> WorldHabitat:
	var result: WorldHabitat = habitat.duplicate(true) as WorldHabitat if habitat!=null else WorldHabitat.new()
	result.habitat_id = stable_id
	result.display_name = display_name
	if result.profile==null: result.profile = SpawnProfile.new()
	result.profile = result.profile.duplicate(true) as SpawnProfile
	var profile: SpawnProfile = result.profile
	profile.target_party_count = party_count
	profile.respawn_min_ms = roundi(respawn_min_seconds*1000)
	profile.respawn_max_ms = roundi(respawn_max_seconds*1000)
	profile.rules = profile.rules.duplicate(true) as EncounterRules
	profile.rules.active = aggressive
	profile.arena_pool = battlefields.duplicate()
	if simple_party:
		var template: PartyTemplate = profile.templates[0].duplicate(true) as PartyTemplate if not profile.templates.is_empty() else PartyTemplate.new()
		if profile.templates.is_empty() and monster!=null:
			template.template_id=stable_id+"_party"
			template.display_name=monster.display_name
		var member: MemberRule = template.members[0].duplicate(true) as MemberRule if not template.members.is_empty() else MemberRule.new()
		template.representative = monster
		member.definition = monster
		member.min_count = minimum_units
		member.max_count = maximum_units
		member.min_level = minimum_level
		member.max_level = maximum_level
		template.members.assign([member])
		profile.templates.assign([template])
		if not profile.weights.is_empty(): profile.weights = PackedFloat32Array([profile.weights[0]])
	if shape_source==ShapeSource.POLYGON:
		var spawn: WorldRegionPolygon = get_node_or_null("SpawnArea") as WorldRegionPolygon
		var roaming: WorldRegionPolygon = get_node_or_null("RoamingArea") as WorldRegionPolygon
		var pursuit: WorldRegionPolygon = get_node_or_null("PursuitArea") as WorldRegionPolygon
		result.spawn_domain = spawn.logical_domain(root) if spawn!=null else PolygonDomain.new()
		result.activity_domain = roaming.logical_domain(root) if roaming!=null else PolygonDomain.new()
		result.chase_domain = pursuit.logical_domain(root) if pursuit!=null else PolygonDomain.new()
	return result
