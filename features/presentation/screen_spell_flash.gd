class_name ScreenSpellFlash
extends CanvasLayer
var rect: ColorRect
var tween: Tween
func _ready() -> void:
	layer=80
	rect=ColorRect.new(); rect.mouse_filter=Control.MOUSE_FILTER_IGNORE
	add_child(rect); rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); rect.hide()
func cancel() -> void:
	if tween!=null: tween.kill()
	if rect!=null: rect.hide()
func play(data: SkillEffectDefinition) -> void:
	cancel()
	rect.color=data.flash_color; rect.color.a=data.flash_opacity; rect.show()
	tween=create_tween(); tween.tween_property(rect,"color:a",0.0,data.flash_duration)
	tween.tween_callback(rect.hide)
