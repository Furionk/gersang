extends Node
const OUT: String = "res://artifacts/monster-layout-2026-10-10/"
class Domains extends Node2D:
	var map: WorldMapDefinition
	func _draw() -> void:
		var palette: Array[Color] = [Color(0.3,0.9,0.7),Color(0.95,0.75,0.3),Color(0.6,0.7,1),Color(1,0.45,0.35)]
		for index: int in map.habitats.size():
			var habitat: WorldHabitat = map.habitats[index]
			var color: Color = palette[index%palette.size()]
			for domain: PolygonDomain in [habitat.activity_domain]:
				var outer: PackedVector2Array = PackedVector2Array()
				for point: Vector2 in domain.outer: outer.append(Iso.project(point))
				draw_colored_polygon(outer,Color(color.r,color.g,color.b,0.11))
				outer.append(outer[0])
				draw_polyline(outer,color,4)
				for hole: PackedVector2Array in domain.holes:
					var points: PackedVector2Array = PackedVector2Array()
					for point: Vector2 in hole: points.append(Iso.project(point))
					points.append(points[0])
					draw_polyline(points,Color(1,0.35,0.35),3)
	# Diagnostic overlay only; never saved into the formal map scene.

func _ready() -> void: call_deferred("run")
func run() -> void:
	var context: WorldContext = WorldContext.new()
	context.initialize(PartyProgress.serialize(),20261011,true)
	var viewport: SubViewport = SubViewport.new()
	viewport.size = Vector2i(1800,1100)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	for id: String in ["river_bay","shaolin_temple"]:
		context.ensure_map(id)
		var map: WorldMapDefinition = context.map_definitions[id]
		var visual: Node2D = Node2D.new()
		visual.y_sort_enabled = true
		viewport.add_child(visual)
		var floor: GroundMap = GroundMap.new()
		floor.build_exploration(visual,map)
		for party: Dictionary in context.state.maps[id].parties.values():
			var view: WorldPartyView = WorldPartyView.new()
			view.context = context
			view.party_id = party.party_id
			visual.add_child(view)
		var zoom: float = 0.165 if id=="river_bay" else 0.45
		visual.scale = Vector2.ONE*zoom
		visual.position = Vector2(900,100)-Vector2(Iso.project(map.extent*0.5).x*zoom,0)
		for frame: int in 3: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_webp(OUT+id+"-monsters.webp",false,0.93)
		var overlay: Domains = Domains.new()
		overlay.map = map
		overlay.z_index = 10
		visual.add_child(overlay)
		for frame: int in 2: await get_tree().process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_webp(OUT+id+"-ranges.webp",false,0.93)
		visual.free()
	print("MONSTER_LAYOUT_CAPTURE complete")
	get_tree().quit()
