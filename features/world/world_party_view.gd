class_name WorldPartyView
extends Node2D
var party_id: String
var context: WorldContext
var sprite: AnimatedSprite2D
var caption: Label
var definition: UnitDefinition
var rainbow_enemy: RainbowEnemyDefinition

func _ready() -> void:
	ScenerySorting.apply_item(self)
	var party: Dictionary = context.party(party_id)
	definition = load(party["representative_path"]) as UnitDefinition
	if context.state.player.map_id == "rainbow_temple":
		var settings: RainbowActionProfile = load("res://features/rainbow/data/default_action.tres")
		for enemy: RainbowEnemyDefinition in settings.enemies:
			if enemy.unit_id == definition.id: rainbow_enemy = enemy; break
	var texture: Texture2D = SpriteAtlas.texture_for(definition)
	var frames: SpriteFrames = SpriteAtlas.frames(texture,definition.sprite_layout)
	var cell: Vector2 = SpriteAtlas.canvas_size(texture,definition.sprite_layout)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.modulate = definition.sprite_tint
	sprite.scale = Vector2.ONE * definition.world_sprite_scale
	sprite.position.y = -(SpriteAtlas.foot(texture,definition.sprite_layout).y-cell.y*0.5)*definition.world_sprite_scale
	add_child(sprite)
	caption = Label.new()
	caption.position = Vector2(-100,4)
	caption.size = Vector2(200,45)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size",12)
	caption.add_theme_color_override("font_color",Color(1,0.85,0.53))
	add_child(caption)

func _process(_delta: float) -> void:
	var party: Dictionary = context.party(party_id)
	if party.is_empty():
		queue_free()
		return
	visible = party["life_state"] == "ACTIVE" or party["life_state"] == "RESERVED"
	position = Iso.project(party["position"])
	var direction: int = Iso.direction_index(party.get("facing",Vector2.DOWN))
	var state: String="walk" if not party["path"].is_empty() else "idle"
	DirectionalAnimation.play(sprite,state,direction,definition.sprite_layout)
	var summary: Dictionary = PowerCalculator.make_summary(party)
	caption.text = "%s\n戰力 %s · %d 名" % [summary["name"],summary["power"],summary["count"]]
	if rainbow_enemy != null and rainbow_enemy.boss and rainbow_enemy.boss_tier != null:
		var tier: RainbowBossTier = rainbow_enemy.boss_tier
		caption.position.x = -170; caption.size.x = 340
		caption.text = "%s ×%d · 建議 Lv%d\n危險 %s · 點選挑戰 · 無等級限制" % [definition.display_name,summary["count"],tier.recommended_level,"★".repeat(tier.tier+1)]
