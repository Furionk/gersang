class_name SceneTransitionCover
extends CanvasLayer
var frame: TextureRect
var shown: bool = false
var logo: TextureRect
func _ready() -> void:
	layer=1000
	frame=TextureRect.new()
	frame.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode=TextureRect.STRETCH_SCALE
	frame.mouse_filter=Control.MOUSE_FILTER_STOP
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.hide()
	var shade: ColorRect=ColorRect.new(); shade.color=Color(0,0,0,0.9); shade.mouse_filter=Control.MOUSE_FILTER_IGNORE; frame.add_child(shade); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var centered: CenterContainer=CenterContainer.new(); centered.mouse_filter=Control.MOUSE_FILTER_IGNORE
	frame.add_child(centered); centered.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	logo=TextureRect.new(); logo.texture=load(str(ProjectSettings.get_setting("application/config/icon", "res://gersang_four.png"))); logo.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; logo.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; logo.mouse_filter=Control.MOUSE_FILTER_IGNORE
	logo.custom_minimum_size=Vector2(360,300); centered.add_child(logo)
func begin() -> void:
	if shown: return # Keep the same last-ready frame through failed/replaced loads.
	shown=true
	if DisplayServer.get_name()!="headless":
		var image: Image = get_viewport().get_texture().get_image()
		if image!=null and not image.is_empty(): frame.texture=ImageTexture.create_from_image(image)
	frame.show()
func complete() -> void:
	shown=false
	frame.hide()
	frame.texture=null
