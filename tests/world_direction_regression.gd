extends Node
var game: GameDirector
var enemy: WorldPartyView
var passed: int = 0
var failures: Array[String] = []
var diagnosis: bool = false
const REQUIRED: Dictionary = {
	"merchant": {3:[Rect2i(211,568,120,145),Rect2i(387,567,119,146)],5:[Rect2i(217,1283,114,150),Rect2i(398,1283,118,147)]},
	"elite": {3:[Rect2i(203,183,165,170),Rect2i(382,183,163,168)],5:[Rect2i(177,903,165,169),Rect2i(360,903,164,168)]}
}
func check(ok: bool, caption: String) -> void:
	if ok: passed+=1; print("PASS | ",caption)
	else: failures.append(caption); push_error("FAIL | "+caption)
func _ready() -> void:
	diagnosis = "--diagnose" in OS.get_cmdline_user_args()
	get_tree().create_timer(30).timeout.connect(func() -> void: get_tree().quit(2))
	call_deferred("run")
func native_direction(row: int) -> void:
	var screen: Vector2 = Vector2.LEFT+Vector2.UP if row==5 else Vector2.LEFT+Vector2.DOWN
	var facing: Vector2 = Iso.unproject(screen).normalized()
	game.world_hero.facing = facing
	game.world_hero.desired_velocity = facing*130
	game.world_hero.view._process(0)
	var party: Dictionary = game.world_context.party(enemy.party_id)
	party["facing"] = facing
	party["path"] = [party["position"]+facing*200]
	enemy._process(0)
func gallery() -> void:
	if DisplayServer.get_name()=="headless": return
	var layer: CanvasLayer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	var panel: Panel = Panel.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var style: StyleBoxFlat = StyleBoxFlat.new()
	style.bg_color = Color("242b29")
	panel.add_theme_stylebox_override("panel",style)
	layer.add_child(panel)
	var heading: Label = Label.new()
	heading.position = Vector2(24,12)
	heading.text = "World directional animation — %s / fixed root cross in green" % ("before" if diagnosis else "after")
	panel.add_child(heading)
	for i: int in 4:
		var row: int = 3 if i%2==0 else 5
		native_direction(row)
		var definition: UnitDefinition = game.world_hero.definition if i<2 else enemy.definition
		var frames: SpriteFrames = game.world_hero.view.sprite.sprite_frames if i<2 else enemy.sprite.sprite_frames
		var texture: Texture2D = load(definition.sprite_path)
		var foot: Vector2 = SpriteAtlas.foot(texture,definition.sprite_layout)
		var extent: Vector2 = SpriteAtlas.canvas_size(texture,definition.sprite_layout)
		var label: Label = Label.new()
		label.position = Vector2(24,75+i*155)
		label.text = "%s\n%s / row %d" % [definition.id,"SW" if row==3 else "NW",row]
		panel.add_child(label)
		for pose: int in 3:
			var root: Node2D = Node2D.new()
			root.position = Vector2(330+pose*335,195+i*155)
			panel.add_child(root)
			var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
			sprite.sprite_frames = frames
			sprite.flip_h = SpriteAtlas.mirrored(definition.sprite_layout,row)
			sprite.scale = Vector2.ONE*0.8
			sprite.position.y = -(foot.y-extent.y*0.5)*0.8
			root.add_child(sprite)
			sprite.play(StringName("%s_%d" % ["idle" if pose==0 else "walk",row]))
			sprite.pause()
			sprite.set_frame_and_progress(0 if pose<2 else 1,0)
			for vertical: bool in [false,true]:
				var marker: ColorRect = ColorRect.new()
				marker.position = Vector2(-1,-6) if vertical else Vector2(-10,-1)
				marker.size = Vector2(2,12) if vertical else Vector2(20,2)
				marker.color = Color("72e894")
				root.add_child(marker)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://artifacts/world/world-directions-%s.png" % ("before" if diagnosis else "after"))
	layer.queue_free()
func run() -> void:
	LegacyPartyFixture.install()
	game = load("res://main.tscn").instantiate() as GameDirector
	add_child(game)
	game.audio.muted = true
	while game.mode!=&"world": await get_tree().process_frame
	game.set_physics_process(false)
	for candidate: WorldPartyView in game.world_views.values():
		if candidate.definition.id==&"elite": enemy=candidate; break
	if enemy==null:
		push_error("Missing real elite world representative fixture")
		get_tree().quit(1)
		return
	await gallery()
	if diagnosis: get_tree().quit(0); return
	check(not PartyProgress.persistence_enabled,"DIR-01 isolated progress")
	for definition: UnitDefinition in [game.world_hero.definition,enemy.definition]:
		var layout: SpriteSheetLayout = definition.sprite_layout
		check(layout!=null,"DIR-02 explicit layout "+str(definition.id))
		if layout==null: continue
		var texture: Texture2D = load(definition.sprite_path)
		check(layout.valid_for(Vector2i(texture.get_width(),texture.get_height())),"DIR-02 valid layout "+str(definition.id))
		for row: int in [3,5]:
			for pose: int in 2:
				var frame: AtlasTexture = SpriteAtlas.frame(texture,layout,row,pose+1)
				check(Rect2i(frame.region).encloses(REQUIRED[str(definition.id)][row][pose]),"DIR-03 full source silhouette %s row%d walk%d" % [definition.id,row,pose])
				check((frame.margin.position+layout.source_pivots[SpriteAtlas.source_row(layout,row)*6+pose+1]).is_equal_approx(layout.foot_point),"DIR-04 fixed pivot %s row%d walk%d" % [definition.id,row,pose])
	var old_fps: int = Engine.max_fps
	var vsync: DisplayServer.VSyncMode = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	for fps: int in [30,120]:
		Engine.max_fps = fps
		for row: int in [3,5]:
			native_direction(row)
			var hero_frames: Dictionary = {}
			var enemy_frames: Dictionary = {}
			var start: int = Time.get_ticks_msec()
			while Time.get_ticks_msec()-start<700:
				await get_tree().process_frame
				hero_frames[game.world_hero.view.sprite.frame] = true
				enemy_frames[enemy.sprite.frame] = true
			check(game.world_hero.view.sprite.animation==StringName("walk_%d" % row) and enemy.sprite.animation==StringName("walk_%d" % row),"DIR-05 actual world actors face %d at %dFPS" % [row,fps])
			check(game.world_hero.view.sprite.flip_h==(row==5) and enemy.sprite.flip_h==(row==3),"DIR-07 corrected diagonal art mapping row%d at %dFPS" % [row,fps])
			check(hero_frames.has(0) and hero_frames.has(1) and enemy_frames.has(0) and enemy_frames.has(1),"DIR-06 both walk phases advance without resets row%d at %dFPS" % [row,fps])
	Engine.max_fps = old_fps
	DisplayServer.window_set_vsync_mode(vsync)
	var file: FileAccess = FileAccess.open("res://artifacts/world/world-direction-%s-results.json" % ("headless" if DisplayServer.get_name()=="headless" else "render"),FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"failed":failures.size(),"failures":failures,"rendered":DisplayServer.get_name()!="headless"},"\t"))
	file.close()
	get_tree().quit(0 if failures.is_empty() else 1)
