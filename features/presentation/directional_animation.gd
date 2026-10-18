@tool
class_name DirectionalAnimation
extends RefCounted
## One native playback authority. Turning preserves weighted clip phase, not just frame number.
static func play(sprite: AnimatedSprite2D, state: String, direction: int, layout: SpriteSheetLayout, restart: bool = false) -> void:
	var name: StringName=StringName("%s_%d"%[state,direction])
	var frames: SpriteFrames=sprite.sprite_frames
	if frames==null or not frames.has_animation(name): return
	sprite.flip_h=SpriteAtlas.mirrored(layout,direction,state)
	if sprite.animation==name and not restart: return
	var keep_phase: bool=not restart and String(sprite.animation).get_slice("_",0)==state and frames.has_animation(sprite.animation)
	var phase: float=phase_of(sprite) if keep_phase else 0.0
	var was_playing: bool=sprite.is_playing()
	sprite.play(name)
	if keep_phase:
		set_phase(sprite,phase)
		if not was_playing: sprite.pause()
	else: sprite.set_frame_and_progress(0,0.0)
static func phase_of(sprite: AnimatedSprite2D) -> float:
	var frames: SpriteFrames=sprite.sprite_frames
	if frames==null or not frames.has_animation(sprite.animation): return 0.0
	var total: float=0.0; var elapsed: float=0.0
	for i: int in frames.get_frame_count(sprite.animation):
		var weight: float=frames.get_frame_duration(sprite.animation,i)
		total+=weight
		if i<sprite.frame: elapsed+=weight
		elif i==sprite.frame: elapsed+=weight*sprite.frame_progress
	return elapsed/maxf(total,0.0001)
static func set_phase(sprite: AnimatedSprite2D, phase: float) -> void:
	var frames: SpriteFrames=sprite.sprite_frames
	var count: int=frames.get_frame_count(sprite.animation)
	var total: float=0.0
	for i: int in count: total+=frames.get_frame_duration(sprite.animation,i)
	var remaining: float=clampf(phase,0.0,1.0)*total
	for i: int in count:
		var weight: float=frames.get_frame_duration(sprite.animation,i)
		if remaining<weight or i==count-1:
			sprite.set_frame_and_progress(i,clampf(remaining/weight,0.0,1.0)); return
		remaining-=weight
