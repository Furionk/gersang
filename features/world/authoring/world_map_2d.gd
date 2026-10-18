@tool
class_name WorldMap2D
extends Node2D
@export var definition: WorldMapDefinition
@export var show_atlas_reference: bool = true
@export var native_tiles_enabled: bool = false

func _ready() -> void:
	ScenerySorting.apply_map(self)
	if not Engine.is_editor_hint():
		call_deferred("_play_isolated")

func _play_isolated() -> void:
	# F6 is a real playable map, but never publishes to the user's save.
	var progress: Node
	var session: Node
	for service: Node in get_tree().root.get_children():
		if service.name == &"PartyProgress": progress = service
		if service.name == &"WorldSession": session = service
	if progress == null or session == null:
		push_error("Map preview requires the project bootstrap services")
		return
	var compiled: WorldMapDefinition = compile_definition()
	WorldCatalog.initialize()
	var errors: Array[String] = WorldValidator.validate(compiled,WorldCatalog.definitions,self)
	if not errors.is_empty():
		push_error("地圖配置無效，停止 F6：\n"+"\n".join(errors))
		return
	for child: Node in get_children():
		if child is CanvasItem: child.hide()
	var context: WorldContext = WorldContext.new()
	context.initialize(progress.call("serialize"),42047,true,{compiled.map_id:compiled})
	context.ensure_map(compiled.map_id)
	context.state["player"]["map_id"] = compiled.map_id
	if not compiled.entries.is_empty():
		context.state["player"]["position"] = compiled.entries.values()[0]["point"]
	progress.set("persistence_enabled",false)
	session.set("context",context)
	var scene: PackedScene = load("res://main.tscn") as PackedScene
	add_child(scene.instantiate())


func compile_definition() -> WorldMapDefinition:
	var compiled: WorldMapDefinition = definition.duplicate(true) as WorldMapDefinition
	# Scene author nodes are canonical, including when the LAST node is deleted.
	compiled.walkable.clear()
	compiled.blockers.clear()
	compiled.habitats.clear()
	compiled.safe_areas.clear()
	compiled.portals.clear()
	compiled.entries.clear()
	compiled.landmarks.clear()
	compiled.roads.clear()
	compiled.scenery.clear()
	var present: Dictionary = {}
	for child: Node in WorldAuthorTree.nodes(self):
		if child is WorldAuthorNode:
			present[child.kind] = true
	if present.has(WorldAuthorNode.Kind.WALKABLE): compiled.walkable.clear()
	if present.has(WorldAuthorNode.Kind.BLOCKER): compiled.blockers.clear()
	if present.has(WorldAuthorNode.Kind.HABITAT): compiled.habitats.clear()
	if present.has(WorldAuthorNode.Kind.SAFE_AREA): compiled.safe_areas.clear()
	if present.has(WorldAuthorNode.Kind.PORTAL): compiled.portals.clear()
	if present.has(WorldAuthorNode.Kind.ARRIVAL): compiled.entries.clear()
	if present.has(WorldAuthorNode.Kind.LANDMARK): compiled.landmarks.clear()
	if present.has(WorldAuthorNode.Kind.ROAD): compiled.roads.clear()
	for child: Node in WorldAuthorTree.nodes(self):
		if NativeScenery.is_author(child):
			compiled.scenery.append(NativeScenery.entry(child,self))
			continue
		if not child is WorldAuthorNode:
			continue
		var author: WorldAuthorNode = child as WorldAuthorNode
		var logical: Vector2 = WorldAuthorTree.logical_position(author,self)
		if author.sprite_definition!=null and author.kind in [WorldAuthorNode.Kind.PORTAL,WorldAuthorNode.Kind.LANDMARK,WorldAuthorNode.Kind.SCENERY]:
			var artwork_basis: Transform2D = WorldAuthorTree.canvas_transform(author,self)
			artwork_basis.origin = Vector2.ZERO
			compiled.scenery.append({"id":author.stable_id,"point":logical,"name":author.display_name,"definition":author.sprite_definition,"artwork_basis":artwork_basis,"sorting_mode":ScenerySorting.mode_for(author),"portal_id":author.stable_id if author.kind==WorldAuthorNode.Kind.PORTAL else ""})
		match author.kind:
			WorldAuthorNode.Kind.WALKABLE:
				if author.domain != null: compiled.walkable.append(author.domain.translated(logical))
			WorldAuthorNode.Kind.BLOCKER:
				if author.domain != null: compiled.blockers.append(author.domain.translated(logical))
			WorldAuthorNode.Kind.SAFE_AREA:
				if author.domain != null: compiled.safe_areas.append(author.domain.translated(logical))
			WorldAuthorNode.Kind.HABITAT:
				if author is WorldMonsterRegion:
					compiled.habitats.append(author.compile_habitat(self))
					continue
				if author.habitat != null:
					var habitat: WorldHabitat = author.habitat.duplicate(true) as WorldHabitat
					habitat.habitat_id = author.stable_id
					habitat.display_name = author.display_name
					habitat.spawn_domain = habitat.spawn_domain.translated(logical)
					habitat.activity_domain = habitat.activity_domain.translated(logical)
					habitat.chase_domain = habitat.chase_domain.translated(logical)
					compiled.habitats.append(habitat)
			WorldAuthorNode.Kind.PORTAL:
				compiled.portals.append({"id":author.stable_id,"point":logical,"radius":author.trigger_radius,"target_map_id":author.target_map_id,"target_entry_id":author.target_entry_id})
			WorldAuthorNode.Kind.ARRIVAL:
				compiled.entries[author.stable_id] = {"point":logical,"facing":author.facing}
			WorldAuthorNode.Kind.LANDMARK:
				compiled.landmarks.append({"name":author.display_name,"point":logical,"kind":author.landmark_kind})
			WorldAuthorNode.Kind.ROAD:
				var points: PackedVector2Array = author.road.duplicate()
				for i: int in points.size(): points[i] += logical
				compiled.roads.append(points)
	if native_tiles_enabled: WorldTileCompiler.apply(compiled,self)
	return compiled

func _draw() -> void:
	if definition == null or not Engine.is_editor_hint():
		return
	if show_atlas_reference and definition.kind == WorldMapDefinition.Kind.EXTERIOR and definition.atlas_projection_scale.x > 0 and definition.atlas_projection_scale.y > 0:
		var texture: Texture2D = load("res://art/ui/classic/cartography-v1.png") as Texture2D
		draw_texture_rect(texture,Rect2(-definition.atlas_projection_origin/definition.atlas_projection_scale,Vector2.ONE/definition.atlas_projection_scale),false,Color(1,1,1,0.45))
	var corners: PackedVector2Array = PackedVector2Array([Vector2.ZERO,Vector2(definition.extent.x,0),definition.extent,Vector2(0,definition.extent.y),Vector2.ZERO])
	for i: int in corners.size(): corners[i] = Iso.project(corners[i])
	draw_polyline(corners,Color(0.7,0.7,0.4),3)
