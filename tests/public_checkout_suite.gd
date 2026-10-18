extends Node

var passed: int = 0
var failed: int = 0

func check(ok: bool, label: String) -> void:
	print("PASS | " if ok else "FAIL | ", label)
	if ok: passed += 1
	else: failed += 1

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	get_tree().create_timer(60).timeout.connect(func() -> void: get_tree().quit(2))
	var music := BackgroundMusic.new()
	add_child(music)
	check(music.players.is_empty(), "public checkout contains no BGM players")
	for name_: String in ["default", "hard", "mania", "despair"]:
		var profile: MonkeyProfile = load("res://features/monkey/data/%s.tres" % name_)
		check(not ResourceLoader.exists(profile.scene), "restricted village scene excluded: " + name_)
		check(profile.resolved_scene() == "res://features/monkey/garden.tscn", "public garden selected: " + name_)
		var garden: MonkeyGarden = load(profile.resolved_scene()).instantiate()
		garden.profile = profile
		add_child(garden)
		await get_tree().physics_frame
		check(garden.monkeys.size() == profile.monkey_count, "configured monkey count preserved: " + name_)
		check(garden.tools.size() == 5 and garden.player != null, "catcher and five tools available: " + name_)
		check(is_equal_approx(garden.time_left, profile.time_limit), "configured timer preserved: " + name_)
		check(garden.stable_ground(garden.safe_point), "fallback spawn has stable ground: " + name_)
		if name_ == "default" and "--capture-public" in OS.get_cmdline_user_args() and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://artifacts/tests/public-checkout")
			get_viewport().get_texture().get_image().save_png("res://artifacts/tests/public-checkout/garden.png")
		garden.queue_free()
		await get_tree().process_frame
	music.queue_free()
	await get_tree().process_frame
	print("PUBLIC_CHECKOUT_RESULT passed=%d failed=%d" % [passed, failed])
	get_tree().quit(0 if failed == 0 else 1)
