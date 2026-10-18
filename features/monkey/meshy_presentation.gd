class_name MonkeyMeshyPresentation
extends RefCounted
## Visual-only adapter. Encounter physics, reach and timing remain in MonkeyGarden.
var garden: Node3D
var skeleton: Skeleton3D
var right_hand: int = -1
var left_hand: int = -1
var rotor: Node3D
var phase: float = 0.0

func setup(owner_: Node3D, character: Node3D) -> void:
	garden=owner_
	skeleton=_skeleton(character)
	if skeleton:
		right_hand=skeleton.find_bone("RightHand")
		left_hand=skeleton.find_bone("LeftHand")
	for asset: String in ["club","net","radar","flyer","hoop"]:
		var model: Node3D=load("res://features/monkey/assets/meshy/"+asset+".glb").instantiate()
		garden.tool_root.add_child(model); garden.tools.append(model)
		model.visible=garden.tools.size()-1==garden.gadget
		if asset=="flyer": rotor=model.find_child("Rotor",true,false)
		if asset=="net": _net_material(model)
	if garden.animation:
		garden.animation.play("Idle"); garden.animation.advance(0)
	tick(0)

func _skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D: return node
	for child: Node in node.get_children():
		var result:=_skeleton(child)
		if result: return result
	return null

func _net_material(node: Node) -> void:
	if node is MeshInstance3D:
		for i: int in node.mesh.get_surface_count():
			var original: Material=node.mesh.surface_get_material(i)
			if original and original.resource_name=="NetWeave":
				var material:=ShaderMaterial.new()
				material.shader=preload("res://features/monkey/data/net_weave.gdshader")
				node.set_surface_override_material(i,material)
	for child: Node in node.get_children(): _net_material(child)

func tick(delta: float) -> void:
	phase+=delta
	var desired: String="Idle"
	var moving: bool=Vector2(garden.player.velocity.x,garden.player.velocity.z).length()>0.2
	if garden.gadget==3: desired="FlyerHold"
	elif garden.swing>=0: desired="NetAttack"
	elif moving: desired="Walk" if garden.sneaking else "Run"
	if garden.animation and garden.animation.has_animation(desired):
		var clip: Animation=garden.animation.get_animation(desired)
		clip.loop_mode=Animation.LOOP_NONE if desired=="NetAttack" else Animation.LOOP_LINEAR
		if garden.animation.current_animation!=desired:
			garden.animation.play(desired,0.08)
		if desired=="NetAttack": garden.animation.seek(garden.swing,true)
	var hand: Vector3=garden.visual.to_global(Vector3(0.32,1.0,-0.24))
	if skeleton and right_hand>=0:
		hand=skeleton.to_global(skeleton.get_bone_global_pose(right_hand).origin)
	garden.tool_root.global_position=hand
	if garden.swing<0: garden.tool_root.rotation=Vector3.ZERO
	if garden.gadget==1 and garden.swing>=0:
		var drop: float=clampf((garden.swing-0.12)/0.16,0,1)
		garden.tool_root.rotation=Vector3(lerpf(0.7,-0.4,drop),0.25,0)
		garden.tool_root.global_position=garden.net_tip(drop)-garden.tool_root.global_basis*Vector3(0,0.025,-1.05)
	for i: int in garden.tools.size():
		garden.tools[i].position=Vector3.ZERO
		garden.tools[i].rotation=Vector3.ZERO
	if garden.gadget==3:
		var middle: Vector3=hand
		if skeleton and left_hand>=0: middle=(hand+skeleton.to_global(skeleton.get_bone_global_pose(left_hand).origin))*0.5
		garden.tool_root.global_position=middle+Vector3.UP*0.23
		garden.tool_root.rotation=Vector3.ZERO
		if rotor: rotor.rotation.y=phase*30.0 if garden.using_tool else 0.0
	elif garden.gadget==4:
		garden.tool_root.position=Vector3(0,0.78,0)
		garden.tools[4].rotation.y=phase*22.0 if garden.using_tool else 0.0
