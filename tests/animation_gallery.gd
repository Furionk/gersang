extends Node
func _ready() -> void:
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	var background: ColorRect = ColorRect.new()
	background.size = Vector2(1280, 720)
	background.color = Color(0.055, 0.065, 0.059)
	layer.add_child(background)
	var font: SystemFont = SystemFont.new()
	font.font_names = PackedStringArray(["Microsoft JhengHei", "sans-serif"])
	var title: Label = Label.new()
	title.text = "鐵衛 · 八方向與動作驗證 / 2D sprite 動畫初版"
	title.position = Vector2(24, 14)
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 23)
	title.modulate = Color(0.94, 0.80, 0.53)
	layer.add_child(title)
	var texture: Texture2D = load("res://features/units/art/guard.png") as Texture2D
	var helper: UnitView = UnitView.new()
	var frames: SpriteFrames = helper._make_frames(texture)
	helper.free()
	var states: Array[String] = ["idle", "walk", "attack", "cast", "dead"]
	for column: int in 8:
		var heading: Label = Label.new()
		heading.text = ["東", "東南", "南", "西南", "西", "西北", "北", "東北"][column]
		heading.position = Vector2(145 + column * 140, 56)
		heading.add_theme_font_override("font", font)
		layer.add_child(heading)
		for row: int in states.size():
			var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
			sprite.sprite_frames = frames
			sprite.position = Vector2(162 + column * 140, 146 + row * 116)
			sprite.scale = Vector2.ONE * 0.53
			sprite.play(StringName("%s_%d" % [states[row], column]))
			layer.add_child(sprite)
	for row: int in 5:
		var label: Label = Label.new()
		label.text = ["待機", "行走", "攻擊", "施法", "倒下"][row]
		label.position = Vector2(25, 131 + row * 116)
		label.add_theme_font_override("font", font)
		layer.add_child(label)
