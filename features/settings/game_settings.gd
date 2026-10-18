extends Node
signal changed
const PROFILE_FIELDS: Array[String] = ["movement_multiplier", "turn_speed", "detection_multiplier", "attack_windup", "cast_multiplier", "repeat_interval", "collision_radius", "camera_speed", "stop_reacquire_delay", "ui_scale", "held_repeat_enabled", "reserved_repeat_enabled", "sequence_enabled"]
const DEFAULT_KEYS: Dictionary = {"toggle_cursor_lock": KEY_F1, "command_move": KEY_M, "command_attack": KEY_A, "command_stop": KEY_S, "command_hold": KEY_H, "skill_blast": KEY_I, "skill_lightning": KEY_T, "skill_supply": KEY_F, "skill_control": KEY_C, "sequence_cast": KEY_E, "open_menu": KEY_X, "select_all": KEY_TAB, "camera_left": KEY_LEFT, "camera_right": KEY_RIGHT, "camera_up": KEY_UP, "camera_down": KEY_DOWN, "modifier_shift": KEY_SHIFT, "modifier_ctrl": KEY_CTRL}
const ACTION_LABELS: Dictionary = {"command_move": "移動", "command_attack": "攻擊", "command_stop": "停止", "command_hold": "駐守", "skill_blast": "爆雷擊", "skill_lightning": "雷擊術", "skill_supply": "補給術", "skill_control": "縛魂術"}
@export var profile: CombatFeelProfile = CombatFeelProfile.new()
var bindings: Dictionary = {}
var skill_labels: Dictionary = {}
var skill_defaults: Dictionary = {}
var key_overrides: Dictionary = {}
# Migration only: old versions saved generated defaults as if they were overrides.
const LEGACY_SKILL_KEYS: Dictionary = {"skill_blast":KEY_I,"skill_lightning":KEY_T,"skill_supply":KEY_F,"skill_control":KEY_C,"skill_quake":KEY_G,"skill_wheel":KEY_B,"skill_dragon":KEY_R,"skill_summon":KEY_D,"skill_ice_wall":KEY_V}
func register_skill(skill: SkillDefinition) -> void:
	if not skill.manual() or skill.action == &"":
		return
	var action: String = String(skill.action)
	skill_labels[action] = skill.display_name
	skill_defaults[action] = skill.default_key
	var key: int = int(key_overrides.get(action,skill.default_key))
	_bind(action, KEY_NONE if key in [KEY_F1,KEY_F2] else key)
var mouse_repeat_action: StringName = &""
var settings_path: String = DemoRules.path("combat_feel.cfg")
var support_modes:Dictionary={}
var control_groups:Dictionary={}
var ui_feedback_volume:float=0.8
var ui_feedback_muted:bool=false
var unit_voice_volume: float = 0.85
var unit_voice_muted: bool = false
func set_unit_voice(volume: float, muted: bool) -> void:
	unit_voice_volume = clampf(volume, 0.0, 1.0)
	unit_voice_muted = muted
	save_settings()
func set_feel(field: String, value: Variant) -> void:
	if field not in PROFILE_FIELDS:
		return
	profile.set(field, value)
	save_settings()
func _ready() -> void:
	load_settings()
	for action: String in DEFAULT_KEYS:
		if action.begins_with("skill_"): continue # Skill Resource is authoritative.
		var key: int = int(bindings.get(action,DEFAULT_KEYS[action]))
		_bind(action, DEFAULT_KEYS[action] if key in [KEY_F1,KEY_F2] and action!="toggle_cursor_lock" else key)
	_bind("open_menu",KEY_X) # X is reserved for menus, independent of legacy Esc bindings.
	_bind("toggle_cursor_lock",KEY_F1)
	for i: int in 10:
		_bind("group_%d" % i, KEY_0 + i)
	for definition: UnitDefinition in Catalog.party():
		for skill: SkillDefinition in definition.skills: register_skill(skill)
func _bind(action: String, key: int) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	InputMap.action_erase_events(action)
	if key!=KEY_NONE:
		var event: InputEventKey = InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	bindings[action] = key
func rebind(action: String, key: int) -> bool:
	if action in ["toggle_cursor_lock","open_menu"] or (action not in DEFAULT_KEYS and action not in skill_labels) or key in [KEY_NONE, KEY_F1, KEY_F2, KEY_X, KEY_MINUS, KEY_EQUAL, KEY_ESCAPE, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META, KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN] or (key >= KEY_0 and key <= KEY_9):
		return false
	var previous: int = int(bindings.get(action, DEFAULT_KEYS.get(action, KEY_NONE)))
	for existing: String in bindings.keys():
		if existing != action and int(bindings.get(existing, 0)) == key:
			_bind(existing, previous)
			key_overrides[existing]=previous
	_bind(action, key)
	key_overrides[action]=key
	save_settings()
	return true
func key_label(action: String) -> String:
	var key: int = int(bindings.get(action,skill_defaults.get(action,DEFAULT_KEYS.get(action,0))))
	return OS.get_keycode_string(key) if key!=KEY_NONE else "未綁定"
func load_settings() -> void:
	unit_voice_volume = 0.85
	unit_voice_muted = false
	support_modes.clear();control_groups.clear()
	ui_feedback_volume=0.8;ui_feedback_muted=false
	bindings.clear()
	key_overrides.clear()
	var cfg: ConfigFile = ConfigFile.new()
	if cfg.load(settings_path) != OK:
		return
	unit_voice_volume = clampf(float(cfg.get_value("audio", "unit_voice_volume", 0.85)), 0.0, 1.0)
	unit_voice_muted = bool(cfg.get_value("audio", "unit_voice_muted", false))
	support_modes=cfg.get_value("battle_ui","support_modes",{})
	control_groups=cfg.get_value("battle_ui","control_groups",{})
	ui_feedback_volume=clampf(float(cfg.get_value("audio","ui_feedback_volume",0.8)),0,1)
	ui_feedback_muted=bool(cfg.get_value("audio","ui_feedback_muted",false))
	for field: String in PROFILE_FIELDS:
		profile.set(field, cfg.get_value("feel", field, profile.get(field)))
	for action: String in cfg.get_section_keys("keys") if cfg.has_section("keys") else PackedStringArray():
		var key: int = int(cfg.get_value("keys",action,KEY_NONE))
		if int(cfg.get_value("meta","key_schema",1))<2 and action.begins_with("skill_") and key==int(LEGACY_SKILL_KEYS.get(action,KEY_NONE)):
			continue
		key_overrides[action]=key
		if not action.begins_with("skill_"): bindings[action]=key
func save_settings() -> void:
	var cfg: ConfigFile = ConfigFile.new()
	cfg.load(settings_path)
	if cfg.has_section("keys"): cfg.erase_section("keys")
	cfg.set_value("audio", "unit_voice_volume", unit_voice_volume)
	cfg.set_value("audio", "unit_voice_muted", unit_voice_muted)
	cfg.set_value("audio","ui_feedback_volume",ui_feedback_volume)
	cfg.set_value("audio","ui_feedback_muted",ui_feedback_muted)
	cfg.set_value("battle_ui","support_modes",support_modes)
	cfg.set_value("battle_ui","control_groups",control_groups)
	cfg.set_value("meta","key_schema",2)
	for field: String in PROFILE_FIELDS:
		cfg.set_value("feel", field, profile.get(field))
	for action: String in key_overrides:
		cfg.set_value("keys", action, key_overrides[action])
	var error: Error = cfg.save(settings_path)
	if error != OK:
		push_error("Could not save settings: %s" % error)
	changed.emit()
func reset_defaults() -> void:
	ui_feedback_volume = 0.8
	ui_feedback_muted = false
	unit_voice_volume = 0.85
	unit_voice_muted = false
	key_overrides.clear()
	profile = CombatFeelProfile.new()
	for action: String in DEFAULT_KEYS:
		_bind(action, int(DEFAULT_KEYS[action]))
	for action: String in skill_defaults:
		_bind(action, int(skill_defaults[action]))
	save_settings()

func reset_skill_binding(action: String) -> void:
	key_overrides.erase(action)
	_bind(action,int(skill_defaults.get(action,KEY_NONE)))
	save_settings()

func set_support_mode(identity:String,skill_id:StringName,enabled:bool)->void:
	if identity.is_empty():return
	support_modes[identity+":"+str(skill_id)]=enabled
	save_settings()

func set_ui_audio(volume:float,muted_value:bool)->void:
	ui_feedback_volume=clampf(volume,0,1);ui_feedback_muted=muted_value
	save_settings()
