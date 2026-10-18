@tool
class_name EncounterRules
extends Resource
## 是否主動發現並追擊玩家；不等於一定加入旁邊的戰圈。
@export var active: bool = false
## 玩家點怪後接近至此距離才能發起遭遇。
@export var interaction_radius: float = 90.0
## 主動怪發現玩家的距離，仍需合法通路。
@export var aggro_radius: float = 250.0
## 主動追擊怪接近玩家到此距離時發起遭遇。
@export var engage_radius: float = 80.0
## 遇怪倒數毫秒；目前預設5000=5秒。
@export var countdown_ms: int = 5000
@export_group("附近增援")
## 最後入場的敵隊批數上限，含第一批，最多4。
@export_range(1, 4) var max_enemy_parties: int = 4
## 倒數期間願意考慮靠近的周邊搜索距離。
@export_range(0, 1000) var reinforcement_radius: float = 320.0
## 每次檢查願意靠近的機率；兵種override非負時優先。
@export_range(0, 1) var reinforcement_chance: float = 0.35
## 每隔多少毫秒重新考慮靠近／加入。1000代表每秒；不是每個60Hz tick抽機率。
@export_range(100,3000,100) var reinforcement_check_ms: int = 1000
## 近身後真正加入的機率；沒有達到Join Distance的怪不能加入。
@export_range(0,1,0.01) var reinforcement_join_chance: float = 0.65
## 接近至這個世界距離才可判定加入。圈內仍須有合法路徑／位置。
@export_range(32,100,1) var reinforcement_join_distance: float = 48.0
## 可同時猶豫／靠近的怪隊數，並非入場批數；最後仍受4批／60人限制。
@export_range(1,16) var max_approaching_parties: int = 8
## 追擊最長毫秒，超時返巢。
@export var chase_timeout_ms: int = 12000
## 戰場回圖後保護玩家的毫秒。
@export var return_protection_ms: int = 3000
## 取消／回圖後避免立即重遇的毫秒。
@export var reengage_cooldown_ms: int = 1000
