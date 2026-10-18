class_name UnitView
extends Node2D
var unit: TacticalUnit
var sprite: AnimatedSprite2D
var selected: bool = false
var group_label:String=""
var elapsed: float = 0.0
var last_animation: StringName = &""
var step_time: float = 0.0
var textures: Texture2D
var bar_y: float = -65.0
var base_sprite_position: Vector2
var confirmation_left: float = 0.0
var confirmations: int = 0
var visual_action: String = ""
var action_layout: SpriteSheetLayout
static var frame_cache: Dictionary = {}
static var top_cache: Dictionary = {}
func initialize(actor: TacticalUnit) -> void:
	unit = actor
	ScenerySorting.apply_item(self)
	sprite = AnimatedSprite2D.new()
	sprite.name = "DirectionalSprite"
	sprite.modulate = actor.definition.sprite_tint
	add_child(sprite)
	sprite.animation_finished.connect(_on_animation_finished)
	actor.visual_action_started.connect(_on_visual_action_started)
	textures=SpriteAtlas.texture_for(actor.definition)
	if textures!=null:
		var layout: SpriteSheetLayout = actor.definition.sprite_layout
		sprite.sprite_frames = SpriteAtlas.frames(textures,layout)
		if layout!=null and not layout.valid_for(Vector2i(textures.get_size())):
			actor.view=self
			return
		var cell: Vector2 = SpriteAtlas.canvas_size(textures,layout)
		var multiplier: float = actor.definition.battle_sprite_scale
		if multiplier<0: multiplier=0.62 if actor.definition.role == 10 else 0.47 if actor.definition.role == 9 else 0.4 # Legacy only; new art has an explicit author value.
		multiplier*=actor.definition.visual_scale
		sprite.scale = Vector2.ONE * multiplier
		sprite.position.y = -(SpriteAtlas.foot(textures,layout).y-cell.y*0.5)*multiplier
		var standing_frame: AtlasTexture = SpriteAtlas.frame(textures,layout,2,layout.columns_for("idle")[0] if layout!=null else 0)
		var top_key: String = textures.resource_path+str(textures.get_rid())+str(standing_frame.region)+str(standing_frame.margin)
		if not top_cache.has(top_key):
			var standing: Image = textures.get_image().get_region(Rect2i(standing_frame.region))
			top_cache[top_key] = standing.get_used_rect().position.y+standing_frame.margin.position.y
		bar_y = sprite.position.y+(float(top_cache[top_key])-cell.y*0.5)*multiplier-8.0
		if actor.definition.movement_type == UnitDefinition.Movement.AIR:
			sprite.position.y -= 18
			bar_y -= 18
		base_sprite_position = sprite.position
	else:
		push_error("Missing original sprite atlas: %s" % actor.definition.sprite_path)
	actor.view = self
func visual_layout() -> SpriteSheetLayout:
	return action_layout if action_layout != null else unit.definition.sprite_layout

func set_action_skin(layout: SpriteSheetLayout, multiplier: float) -> void:
	# This view belongs to the encounter; persistent definition and stats are untouched.
	if layout == null or layout.source_texture == null or not layout.valid_for(Vector2i(layout.source_texture.get_size())): return
	action_layout = layout
	textures = layout.source_texture
	sprite.sprite_frames = SpriteAtlas.frames(textures, layout)
	sprite.scale = Vector2.ONE * multiplier
	sprite.position = Vector2(0, -(layout.foot_point.y - layout.frame_size.y * 0.5) * multiplier)
	base_sprite_position = sprite.position
	bar_y = -layout.source_pivots[0].y * multiplier - 8
	visual_action = ""
	show_entry_pose()

func _make_frames(texture: Texture2D) -> SpriteFrames:
	return SpriteAtlas.frames(texture,visual_layout() if unit!=null else null)
func show_entry_pose() -> void:
	visual_action=""
	DirectionalAnimation.play(sprite,"idle",Iso.direction_index(unit.facing),visual_layout(),true)
	last_animation=sprite.animation
func _on_visual_action_started(action: String) -> void:
	visual_action=action
	DirectionalAnimation.play(sprite,action,Iso.direction_index(unit.facing),visual_layout(),true)
	var skill: SkillDefinition=unit.active.get("skill") if action=="cast" else null
	var clip: SpriteAnimationClip=visual_layout().clip_for(action) if visual_layout()!=null else null
	if skill!=null and skill.cast_time<=0 and clip!=null:
		sprite.set_frame_and_progress(clip.instant_start_frame,0.0)
	last_animation=sprite.animation
func _on_animation_finished() -> void:
	if String(sprite.animation).get_slice("_",0)==visual_action: visual_action=""
func _process(delta: float) -> void:
	if not is_instance_valid(unit):
		queue_free()
		return
	elapsed += delta
	sprite.modulate=unit.definition.sprite_tint*Color(0.5,0.52,0.55) if unit.petrified_left>0 else unit.definition.sprite_tint
	_update_confirmation(delta)
	var visual_position: Vector2 = unit.director.world_visual_position() if unit == unit.director.world_hero and unit.director.mode in [&"world",&"countdown"] else unit.position
	if unit.director.mode == &"battle" and is_instance_valid(unit.director.action_battle):
		visual_position = unit.director.action_battle.sample_position(unit.unit_id)
	position = Iso.project(visual_position)
	var state: String = "idle"
	if unit.fsm.current == &"dead":
		state = "dead"
	elif unit.channeling or unit.fsm.current == &"cast" or unit.cast_visual_left > 0:
		state = "cast"
	elif unit.attack_windup_left >= 0.0:
		state = "attack"
	elif unit.desired_velocity.length_squared() > 3.0:
		state = "walk"
	# A short/instant cast must still show its authored recovery. Movement, control
	# and death interrupt visuals immediately; never delay the actual command.
	if state=="idle" and unit.control_left<=0 and not visual_action.is_empty(): state=visual_action
	elif state in ["dead","walk"] or unit.control_left>0: visual_action=""
	var action_actor: RainbowActionActor
	if action_layout != null and is_instance_valid(unit.director.action_battle):
		action_actor = unit.director.action_battle.actors.get(unit.unit_id)
		if action_actor != null and state != "dead":
			if action_actor.action != &"" or action_actor.swing_pose_left > 0: state = "attack"
			elif state == "attack":
				visual_action = ""
				state = "walk" if unit.desired_velocity.length_squared() > 3 else "idle"
	var direction: int = Iso.direction_index(unit.facing)
	var animation: StringName = StringName("%s_%d" % [state,direction])
	if sprite.sprite_frames != null and sprite.sprite_frames.has_animation(animation):
		DirectionalAnimation.play(sprite,state,direction,visual_layout())
		last_animation = animation
		if state == "cast":
			sprite.speed_scale = 0.5 / maxf(0.1, GameSettings.profile.cast_multiplier)
		elif state == "walk":
			var speed_factor: float = float(unit.combat_stats["speed"]) / maxf(1,unit.definition.speed)
			sprite.speed_scale = GameSettings.profile.movement_multiplier * speed_factor * unit.statuses.speed_multiplier()
		else:
			sprite.speed_scale = 1.0
	if action_layout != null:
		# New action skins hold anticipation until the actual authoritative release.
		if action_actor != null and state == "attack":
			sprite.speed_scale = 0
			sprite.set_frame_and_progress(0 if action_actor.action != &"" else 1 if action_actor.swing_pose_left > 0.05 else 2, 0)
		sprite.rotation = -PI * 0.45 if state == "dead" else 0.0
		if state == "dead": sprite.self_modulate.a = 0.45
	if state == "walk":
		step_time += delta
		if selected and step_time > 0.28:
			unit.director.audio.play("step")
			step_time = 0.0
	sprite.position = base_sprite_position
	if unit.shake_left > 0:
		sprite.position += Vector2(sin(elapsed * 90), cos(elapsed * 81)) * 2.0
	queue_redraw()
func confirm_target() -> void:
	confirmations += 1
	confirmation_left = 0.32
	_update_confirmation(0)
func _update_confirmation(delta: float) -> void:
	confirmation_left = maxf(0,confirmation_left-delta)
	if sprite != null:
		sprite.self_modulate.a = 0.22 if unit!=null and unit.statuses.hidden() else 0.3 if confirmation_left>0 and int((0.32-confirmation_left)*18)%2==0 else 1.0
func _draw() -> void:
	if unit == null:
		return
	draw_set_transform(Vector2.ZERO, 0.0, Vector2(1.0, 0.45))
	draw_circle(Vector2.ZERO, 23.0 if unit.definition.role < 9 else 31.0, Color(0.01, 0.01, 0.01, 0.34))
	if selected and unit.alive():
		draw_arc(Vector2.ZERO, 24.0, 0.0, TAU, 40, Color(0.55, 0.93, 0.5), 2.5)
	draw_set_transform(Vector2.ZERO)
	if unit.alive():
		var width: float = 40.0
		if not group_label.is_empty():
			var font:Font=ThemeDB.fallback_font
			var extent:Vector2=font.get_string_size(group_label,HORIZONTAL_ALIGNMENT_LEFT,-1,12)
			draw_rect(Rect2(Vector2(-width*0.5-extent.x-6,bar_y-12),Vector2(extent.x+4,16)),Color(0.02,0.025,0.025,0.9))
			draw_string(font,Vector2(-width*0.5-extent.x-4,bar_y),group_label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color(1,0.9,0.5))
		var hp: float = unit.vitals.health / unit.vitals.max_health
		draw_rect(Rect2(-width * 0.5, bar_y, width, 4.0), Color(0.06, 0.03, 0.02))
		draw_rect(Rect2(-width * 0.5, bar_y, width * hp, 3.0), Color(0.3, 0.83, 0.37) if unit.team == 0 else Color(0.82, 0.22, 0.17))
		if unit.vitals.max_mana > 0.0:
			draw_rect(Rect2(-width * 0.5, bar_y + 6.0, width * unit.vitals.mana / unit.vitals.max_mana, 2.0), Color(0.31, 0.57, 0.92))
		if unit.control_left > 0.0:
			draw_arc(Vector2(0, -70), 12.0, elapsed, elapsed + PI * 1.5, 16, Color(0.83, 0.52, 1.0), 2.0)
