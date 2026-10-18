class_name WorldMapProjection
extends Node
## Presentation-only canvas shared by the two map cameras. No actors or simulation.
var viewport: SubViewport
var presentation: Node2D
var ground: GroundMap
var definition: WorldMapDefinition
var bounds: Rect2 = Rect2(-1,-1,2,2)
var revision: int = 0

func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "MapSceneryCanvas"
	viewport.world_2d = World2D.new()
	viewport.disable_3d = true
	viewport.gui_disable_input = true
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)

func show_map(data: WorldMapDefinition) -> void:
	if definition == data: return
	definition = data
	if presentation != null:
		viewport.remove_child(presentation)
		presentation.queue_free()
	presentation = Node2D.new()
	presentation.name = "AuthoredMapPresentation"
	presentation.y_sort_enabled = true
	presentation.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	viewport.add_child(presentation)
	ground = GroundMap.new()
	ground.build_exploration(presentation,data)
	# UI owns labels so they remain legible at every map scale.
	for label: Node in presentation.find_children("*","Label",true,false):
		(label as Label).hide()
	bounds = Rect2(Iso.project(Vector2.ZERO),Vector2.ZERO)
	for point: Vector2 in [Vector2(data.extent.x,0),data.extent,Vector2(0,data.extent.y)]:
		bounds = bounds.expand(Iso.project(point))
	for view: WorldSceneryView in ground.scenery_views:
		if view.sprite == null: continue
		var sprite_rect: Rect2 = Rect2(view.position+view.sprite.position,view.sprite.texture.get_size()*view.sprite.scale)
		bounds = bounds.merge(sprite_rect)
	bounds = bounds.grow(64)
	revision += 1
