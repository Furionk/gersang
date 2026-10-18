@tool
class_name NativeScenery
extends RefCounted
static func is_author(node: Node) -> bool:
	if not node is Sprite2D: return false
	if node.has_meta("world_scenery_id"): return true
	var parent: Node = node.get_parent()
	while parent!=null:
		if parent is WorldAuthorNode or parent is Sprite2D: return false
		if parent.name==&"Scenery": return true
		parent=parent.get_parent()
	return false
static func copy_sprite(source: Sprite2D, target: Sprite2D) -> void:
	target.visible=source.visible
	for field: String in ["texture","hframes","vframes","frame_coords","centered","offset","region_enabled","region_rect","region_filter_clip_enabled","flip_h","flip_v","modulate","self_modulate","z_index","z_as_relative","show_behind_parent","texture_filter","texture_repeat","material","y_sort_enabled"]:
		target.set(field,source.get(field))
	for key: StringName in source.get_meta_list(): target.set_meta(key,source.get_meta(key))
static func entry(sprite: Sprite2D, root: Node) -> Dictionary:
	var style: WorldSceneryDefinition = sprite.get_meta("world_scenery_definition") as WorldSceneryDefinition if sprite.has_meta("world_scenery_definition") else null
	var data: WorldSceneryDefinition = style.duplicate(true) if style!=null else WorldSceneryDefinition.new()
	var texture: Texture2D = sprite.texture
	var region: Rect2 = Rect2(Vector2.ZERO,texture.get_size()) if texture!=null else Rect2()
	if texture is AtlasTexture:
		region=texture.region
		texture=texture.atlas
	if sprite.region_enabled: region=Rect2(region.position+sprite.region_rect.position,sprite.region_rect.size)
	var frame_size: Vector2 = region.size/Vector2(sprite.hframes,sprite.vframes)
	region=Rect2(region.position+Vector2(sprite.frame_coords)*frame_size,frame_size)
	data.texture=texture
	data.atlas_region=region
	var transform: Transform2D = WorldAuthorTree.canvas_transform(sprite,root)
	var offset: Vector2 = sprite.offset-(region.size*0.5 if sprite.centered else Vector2.ZERO)
	var flip: Transform2D = Transform2D(Vector2(-1 if sprite.flip_h else 1,0),Vector2(0,-1 if sprite.flip_v else 1),Vector2.ZERO)
	var shift: Vector2 = Vector2(region.size.x if sprite.flip_h else 0,region.size.y if sprite.flip_v else 0)
	data.foot_anchor=-(flip.basis_xform(offset+shift))
	transform.origin=Vector2.ZERO
	data.sprite_basis=transform*flip
	data.sprite_scale=1.0
	data.tint=sprite.modulate*sprite.self_modulate
	data.sorting_mode=ScenerySorting.mode_for(sprite)
	var preset: WorldSceneryDefinition = ScenerySorting.preset_for(sprite)
	if preset!=null:
		data.sorting_review_required=preset.sorting_review_required
		data.sorting_note=preset.sorting_note
	return {"id":str(sprite.get_meta("world_scenery_id","")),"point":Iso.unproject(WorldAuthorTree.canvas_transform(sprite,root).origin),"name":str(sprite.get_meta("world_scenery_label",sprite.name)),"definition":data,"artwork_basis":Transform2D.IDENTITY,"portal_id":"","visible":sprite.visible,"sorting_mode":data.sorting_mode,"material":sprite.material,"texture_filter":sprite.texture_filter}
static func flatten(pivot: Node2D, artwork: Sprite2D) -> Sprite2D:
	var sprite: Sprite2D = Sprite2D.new()
	copy_sprite(artwork,sprite)
	var combined: Transform2D = pivot.transform*artwork.transform
	var basis: Transform2D = combined; basis.origin=Vector2.ZERO
	sprite.transform=Transform2D(combined.x,combined.y,pivot.position)
	sprite.offset=artwork.offset+basis.affine_inverse().basis_xform(combined.origin-pivot.position)
	sprite.modulate=artwork.modulate*pivot.modulate
	sprite.visible=artwork.visible and pivot.visible
	sprite.z_index=artwork.z_index+(pivot.z_index if artwork.z_as_relative else 0)
	sprite.name=pivot.name
	for key: StringName in pivot.get_meta_list(): sprite.set_meta(key,pivot.get_meta(key))
	return sprite
