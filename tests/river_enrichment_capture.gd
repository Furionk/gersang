extends Node
const OUT: String = "res://artifacts/river-enrichment-2026-10-10/"
var viewport: SubViewport
var visual: Node2D
func _ready() -> void: call_deferred("run")
func run() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1800,1000)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	visual = Node2D.new()
	visual.y_sort_enabled = true
	viewport.add_child(visual)
	for version: String in ["before","after"]:
		var path: String = OUT+"river-before.tscn" if version=="before" else "res://features/world/data/river_bay.tscn"
		var source: WorldMap2D = ResourceLoader.load(path,"PackedScene",ResourceLoader.CACHE_MODE_IGNORE).instantiate() as WorldMap2D
		var data: WorldMapDefinition = source.compile_definition()
		source.free()
		var floor: GroundMap = GroundMap.new()
		floor.build_exploration(visual,data)
		var started: int = Time.get_ticks_msec()
		visual.scale = Vector2.ONE*0.16
		visual.position = Vector2(900,70)-Iso.project(data.extent*0.5)*0.16
		# Correct vertical framing: map diamond top starts near y70.
		visual.position.y = 70
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		viewport.get_texture().get_image().save_png(OUT+version+"-overview.png")
		for pair: Array in [["town",Vector2(4450,2820)],["forest",Vector2(2900,1300)],["river",Vector2(1250,2050)],["mountain",Vector2(1500,3200)]]:
			visual.scale = Vector2.ONE
			visual.position = Vector2(900,550)-Iso.project(pair[1])
			for i: int in 3: await get_tree().process_frame
			await RenderingServer.frame_post_draw
			viewport.get_texture().get_image().save_png(OUT+version+"-"+pair[0]+".png")
		print("PASS | capture ",version," scenery=",data.scenery.size()," capture_ms=",Time.get_ticks_msec()-started)
		for child: Node in visual.get_children(): child.free()
	print("RIVER_CAPTURE_COMPLETE")
	get_tree().quit()
