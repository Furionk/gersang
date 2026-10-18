class_name GameAudio
extends Node
const FEEDBACK:UiFeedbackProfile=preload("res://features/ui/data/feedback.tres")
var ui_player:AudioStreamPlayer
var ui_sounds:Dictionary={}
var feedback_count:int=0
var last_feedback:String=""
var player: AudioStreamPlayer
var sounds: Dictionary = {}
var muted: bool = false
var web_test_callback: JavaScriptObject
var peak_probe_left: float=0
var peak_probe_db: float=-200
func _ready() -> void:
	ui_player=AudioStreamPlayer.new();ui_player.max_polyphony=4;add_child(ui_player)
	for kind:String in ["prepare","confirm","cancel","error"]:
		var authored:AudioStream=FEEDBACK.get(kind+"_sound")
		ui_sounds[kind]=authored if authored!=null else _ui_tone(float(FEEDBACK.get(kind+"_frequency")))
	if OS.has_feature("web"):ui_player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
	player = AudioStreamPlayer.new()
	player.max_polyphony = 16
	player.volume_db = -19.0
	add_child(player)
	for kind: String in ["select", "step", "attack", "hit", "cast", "win"]:
		sounds[kind] = _tone(kind)
	if OS.has_feature("web"):
		player.playback_type=AudioServer.PLAYBACK_TYPE_STREAM
		var host: JavaScriptObject=JavaScriptBridge.get_interface("gersangWeb")
		if host!=null:
			web_test_callback=JavaScriptBridge.create_callback(func(_arguments:Array)->void:
				peak_probe_left=0.8; peak_probe_db=-200
				play("win"))
			host.setAudioTest(web_test_callback)

func _process(delta: float) -> void:
	if peak_probe_left<=0: return
	peak_probe_db=maxf(peak_probe_db,AudioServer.get_bus_peak_volume_left_db(0,0))
	peak_probe_left-=delta
	if peak_probe_left<=0:
		var host: JavaScriptObject=JavaScriptBridge.get_interface("gersangWeb")
		if host!=null: host.audioResult(peak_probe_db)
func play(kind: String) -> void:
	if muted or not sounds.has(kind):
		return
	player.stream = sounds[kind]
	player.play()
func _tone(kind: String) -> AudioStreamWAV:
	var rate: int = 22050
	var duration: float = 0.08 if kind == "step" else 0.16 if kind != "win" else 0.6
	var frequency: float = float({"select": 640.0, "step": 90.0, "attack": 180.0, "hit": 120.0, "cast": 880.0, "win": 520.0}[kind])
	var data: PackedByteArray = PackedByteArray()
	data.resize(int(rate * duration) * 2)
	for i: int in int(rate * duration):
		var t: float = float(i) / rate
		var envelope: float = minf(1.0, t / 0.008) * pow(1.0 - t / duration, 2)
		var sample: float = sin(TAU * frequency * t * (1.0 + t * 0.5)) * 0.55 + sin(TAU * frequency * 1.5 * t) * 0.15
		data.encode_s16(i * 2, int(clampf(sample * envelope, -1.0, 1.0) * 20000))
	var stream: AudioStreamWAV = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data
	return stream

func feedback(kind:String)->void:
	if muted or GameSettings.ui_feedback_muted or not ui_sounds.has(kind):return
	last_feedback=kind;feedback_count+=1
	ui_player.volume_db=FEEDBACK.volume_db+linear_to_db(maxf(0.0001,GameSettings.ui_feedback_volume))
	ui_player.stream=ui_sounds[kind];ui_player.play()
func _ui_tone(frequency:float)->AudioStreamWAV:
	var rate:int=22050
	var count:int=int(rate*FEEDBACK.sound_duration)
	var bytes:PackedByteArray=PackedByteArray();bytes.resize(count*2)
	for i:int in count:
		var t:float=float(i)/rate
		var envelope:float=minf(1,t/0.006)*pow(1-float(i)/count,2)
		bytes.encode_s16(i*2,int(sin(TAU*frequency*t)*envelope*15000))
	var stream:AudioStreamWAV=AudioStreamWAV.new();stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.data=bytes
	return stream
