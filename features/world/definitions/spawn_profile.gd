@tool
class_name SpawnProfile
extends Resource
## 此怪區可生成的固定怪隊模板清單。
@export var templates: Array[PartyTemplate] = []
## 各模板抽選權重，依序對應Templates，不需加總為1。
@export var weights: PackedFloat32Array = PackedFloat32Array()
## 怪區目標隊數，不是每隊單位數；增加後會補出生槽。
@export_range(0, 100) var target_party_count: int = 6
## 重生等待時間下限（毫秒），1000毫秒=1秒。
@export var respawn_min_ms: int = 15000
## 重生等待時間上限（毫秒）。
@export var respawn_max_ms: int = 25000
## 主動／被動索敵、倒數與附近增援規則。
@export var rules: EncounterRules = EncounterRules.new()
## 邏輯移動速度，單位為世界單位／秒，不是畫面像素。
@export var speed: float = 85.0
## 效果或區域的邏輯半徑（世界單位）；等角畫面會呈現為橢圓。
@export var radius: float = 16.0
## 遊走前等待毫秒下限。
@export var wander_pause_min_ms: int = 800
## 遊走前等待毫秒上限。
@export var wander_pause_max_ms: int = 2500
## 此怪區可使用的Arena ID，需與已註冊戰場一致。
@export var arena_pool: PackedStringArray = PackedStringArray(["meadow"])
