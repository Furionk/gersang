extends Node
var passed: int = 0
var failed: int = 0
func check(ok: bool, caption: String) -> void:
	print("PASS | " if ok else "FAIL | ",caption)
	if ok: passed+=1
	else: failed+=1
func _ready() -> void:
	get_tree().create_timer(60).timeout.connect(func()->void:get_tree().quit(2))
	call_deferred("run")
func run() -> void:
	var face: Font=load("res://art/fonts/NotoSansCJKtc-Regular.otf")
	var examples: String="魔法學校・霍格愛茲 蛇妖 黑暗妖靈 石像守門人 催狂魔 三頭犬 佛地魔的幻象 加儂的幻影\n戰鬥勝利 暴擊 傷害 擊倒 撤退 繼續 回復 護院\n击伤质级单续来敌数 気静変残薬済頼読乗乱満"
	var covered: bool=true
	for i: int in examples.length():
		if examples.unicode_at(i)>32: covered=covered and face.has_char(examples.unicode_at(i))
	check(covered,"bundled full CJK covers dungeon names, combat text, simplified and Japanese variants")
	check(ProjectSettings.get_setting("gui/theme/custom_font")=="res://art/fonts/NotoSansCJKtc-Regular.otf","global font is bundled on every platform")
	check(not ProjectSettings.has_setting("gui/theme/custom_font.web"),"Web cannot override the full font with the retired subset")
	WorldSession.context.ensure_map("hogwarts")
	WorldSession.context.state.player.map_id="hogwarts"
	WorldSession.context.state.player.position=WorldSession.context.map_definitions.hogwarts.entries.entrance.point
	WorldSession.context.state.player.protected_until_ms=99999999
	var game: GameDirector=load("res://main.tscn").instantiate();add_child(game)
	while game.mode!=&"world":await get_tree().process_frame
	game.set_physics_process(false)
	await get_tree().process_frame
	check(game.hud.font==face,"actual HUD uses the same bundled full font")
	var labels: int=0
	var world_covered: bool=true
	for view: Node in game.render_root.get_children():
		if not view is WorldPartyView: continue
		labels+=1
		var font: Font=view.caption.get_theme_font("font")
		for i: int in view.caption.text.length():
			if view.caption.text.unicode_at(i)>32: world_covered=world_covered and font.has_char(view.caption.text.unicode_at(i))
	check(labels==30 and world_covered,"all30 actual school party captions inherit a font with every character")
	check(game.hud.log_label.get_theme_font("normal_font")==face,"actual battle/world rich-text log uses the full font")
	var overlay: CanvasLayer=CanvasLayer.new();overlay.layer=900;add_child(overlay)
	var panel: ColorRect=ColorRect.new();panel.color=Color(0.035,0.035,0.045,0.96);panel.position=Vector2(160,225);panel.size=Vector2(970,210);overlay.add_child(panel)
	var label: Label=Label.new();label.text=examples;label.position=Vector2(180,250);label.size=Vector2(930,180);label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART;label.add_theme_font_size_override("font_size",23);label.add_theme_color_override("font_color",Color(1,0.87,0.62));overlay.add_child(label)
	check(label.get_theme_font("font")==face,"a new ordinary world label inherits the full global font")
	if DisplayServer.get_name()!="headless":
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://artifacts/tests/font-coverage/render.png")
	print("FONT_UI_RESULT passed=",passed," failed=",failed," world_labels=",labels)
	get_tree().quit(0 if failed==0 else 1)
