class_name RainbowActionFeedback
extends Node
## Local presentation only: never applies damage or changes global time scale.
var battle: RainbowActionBattle
var impacts: Array[Dictionary] = []
var pools: Array[AudioStreamPlayer] = []
var voice: AudioStreamPlayer
var sounds: Dictionary = {}
var voices: Dictionary = {}
var voice_enabled: bool = true
var shake_enabled: bool = true
var shake_left: float = 0.0
var sound_left: float = 0.0
var voice_left: float = 0.0
var elapsed: float = 0.0
var hit_count: int = 0
var voice_count: int = 0
var cursor: int = 0
var last_kind: String = ""
var last_text: String = ""
var notice_left: float = 0.0
var voice_peak_db: float = -200.0

func _ready() -> void:
	for kind: String in ["swing", "cut", "cleave", "bang", "break", "guard"]:
		sounds[kind] = load("res://features/rainbow/audio/" + kind + ".wav")
	for kind: String in ["cut", "cleave", "bang", "break"]:
		voices[kind] = load("res://features/rainbow/audio/voice_" + kind + ".ogg")
	for i: int in 4:
		var player := AudioStreamPlayer.new()
		if OS.has_feature("web"): player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		add_child(player); pools.append(player)
	voice = AudioStreamPlayer.new()
	voice.bus = "UnitVoice"
	if OS.has_feature("web"): voice.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
	add_child(voice)
	for actor: RainbowActionActor in battle.actors.values():
		var material := ShaderMaterial.new()
		material.shader = preload("res://features/rainbow/impact_flash.gdshader")
		actor.unit.view.sprite.material = material

func note(text: String) -> void:
	last_text = text; notice_left = 1.1

func play(kind: String, prominent: bool) -> void:
	if battle.game.audio.muted or (not prominent and sound_left > 0): return
	sound_left = 0.06
	var player: AudioStreamPlayer = pools[cursor % pools.size()]
	cursor += 1
	player.stream = sounds[kind]
	player.volume_db = battle.profile.impact_volume_db - (0 if prominent else 10)
	player.pitch_scale = 0.97 + float(cursor % 4) * 0.025
	player.play()

func impact(source_id: int, victim: RainbowActionActor, damage: float, kind: String, guarded: bool) -> void:
	if damage <= 0: return
	var prominent: bool = source_id == battle.controlled_id
	var cue: String = "guard" if guarded else kind
	var source: RainbowActionActor = battle.actors.get(source_id)
	var tint: Color = source.weapon.tint if source != null else Color(1,0.78,0.26)
	var splash: float = source.weapon.splash if source != null and kind == "bang" else 0.0
	impacts.append({"point":victim.unit.position,"left":0.26,"kind":cue,"strong":prominent,"tint":tint,"splash":splash})
	if impacts.size() > 40: impacts.pop_front()
	play(cue, prominent)
	if prominent:
		hit_count += 1; last_kind = cue
		shake_left = 0.11
		(battle.actors[source_id] as RainbowActionActor).hit_stop = battle.profile.impact_pause
		note("格擋" if guarded else "命中  ·  %d" % int(ceilf(damage)))
		if not guarded and voice_enabled and not battle.game.audio.muted and not GameSettings.unit_voice_muted and GameSettings.unit_voice_volume > 0 and voice_left <= 0:
			battle.game.voices.stop()
			voice.stop(); voice.stream = voices[kind]
			voice.volume_db = battle.profile.comic_voice_volume_db
			voice.play(); voice_count += 1; voice_left = 0.18
	elif victim.unit.unit_id == battle.controlled_id:
		shake_left = 0.08
		note("防禦成功" if guarded else "受擊  ·  側移或正面防禦")

func _process(delta: float) -> void:
	elapsed += delta
	if voice.playing:
		voice_peak_db = maxf(voice_peak_db, AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("UnitVoice"), 0))
	sound_left = maxf(0, sound_left - delta); voice_left = maxf(0, voice_left - delta)
	notice_left = maxf(0, notice_left - delta); shake_left = maxf(0, shake_left - delta)
	for i: int in range(impacts.size() - 1, -1, -1):
		impacts[i].left -= delta
		if impacts[i].left <= 0: impacts.remove_at(i)
	for actor: RainbowActionActor in battle.actors.values():
		var sprite: AnimatedSprite2D = actor.unit.view.sprite
		(sprite.material as ShaderMaterial).set_shader_parameter("flash", actor.hit_flash / maxf(0.01, battle.profile.impact_flash))
		if actor.hit_stop > 0: sprite.speed_scale = 0
	if battle.game.mode != &"battle":
		voice.stop(); impacts.clear(); shake_left = 0
		for player: AudioStreamPlayer in pools: player.stop()
	if not voice_enabled or battle.game.audio.muted or GameSettings.unit_voice_muted: voice.stop()
	battle.game.camera.offset = Vector2(sin(elapsed * 101), cos(elapsed * 83)) * battle.profile.camera_kick * (shake_left / 0.11) if shake_enabled else Vector2.ZERO
	if is_instance_valid(battle.visual): battle.visual.queue_redraw()

func shutdown() -> void:
	battle.game.camera.offset = Vector2.ZERO
	voice.stop()
	for player: AudioStreamPlayer in pools: player.stop()
