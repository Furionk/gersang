class_name MonkeyNetFeedback
extends Node3D
var arena: MonkeyGarden
var ring: MeshInstance3D
var material: StandardMaterial3D
var caption: Label3D
var message: String=""
var message_left: float=0.0
func _ready() -> void:
	ring=MeshInstance3D.new(); var mesh:=TorusMesh.new(); mesh.inner_radius=0.52; mesh.outer_radius=0.58; mesh.rings=32; mesh.ring_segments=8; ring.mesh=mesh; add_child(ring)
	material=StandardMaterial3D.new(); material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED; material.no_depth_test=false; ring.material_override=material
	caption=Label3D.new(); caption.font=load("res://art/fonts/NotoSansCJKtc-Regular.otf"); caption.font_size=42; caption.pixel_size=0.006; caption.billboard=BaseMaterial3D.BILLBOARD_ENABLED; caption.no_depth_test=true; add_child(caption)
func flash(text_: String) -> void:
	message=text_; message_left=0.65
func tick(delta: float) -> void:
	message_left=maxf(0,message_left-delta)
	ring.hide()
	visible=message_left>0 and not arena.finished
	if not visible: return
	global_position=arena.player.global_position+Vector3.UP*1.8
	caption.position=Vector3.ZERO
	caption.modulate=Color.WHITE
	caption.text=message
