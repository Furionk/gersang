class_name UnitDefinition
extends Resource
@export_group("轉珠世界")
@export_enum("火", "水", "草", "電") var puzzle_element: int = 1
## 非空時首次普攻進入轉珠世界；一般兵種留空。
@export var puzzle_monster: PuzzleRules
@export_group("世界配置評分（非傷害）")
## 內容相容版本。提升版本會影響舊世界配置驗證，不要用它當作一般修改的儲存按鈕。
@export var content_revision: int = 1
## 世界配置評分基值，僅用於戰力顯示，不直接當成傷害或判勝負。
@export var base_power: int = 100
## 每級增加的世界戰力評分，不是攻擊成長。
@export var level_power_growth: int = 20
enum Movement { GROUND, AIR }
@export_group("能力")
## 力量基值；參與派生攻擊、防禦、體力與技能公式。
@export var strength: float = 20.0
## 敏捷基值；參與命中、閃避、移速與技能公式。
@export var agility: float = 20.0
## 體質基值，供技能公式及能力資料使用。
@export var vitality: float = 20.0
## 智力基值；參與法力與技能公式。
@export var intelligence: float = 20.0
## 幸運基值；參與命中、暴擊、閃避與技能公式。
@export var luck: float = 20.0
## 派生能力計算規則Resource。共用引用時變更會影響多種兵。
@export var stat_rules: CombatStatRules
## 基礎物理防禦，實際防禦會套用派生能力與隨機幅度。
@export var defense: float = 0.0
## 基礎命中評分，與敵人閃避對抗；不負責減傷。
@export var accuracy: float = 100.0
## 基礎閃避機率；0.1代表10%。
@export_range(0, 0.8) var evasion: float = 0.0
## 法術減傷比例，0.2代表20%。
@export_range(0, 0.9) var magic_resistance: float = 0.0
## 擊敗此單位的經驗基值，正式遭遇由一次性結算服務發放。
@export var experience_reward: int = 20
## 初始／模板等級；實際怪隊等級還由配怪Member Rule決定。
@export var level: int = 1
## GROUND地面或AIR飛行；飛行不受冰牆的地面阻擋影響。
@export var movement_type: Movement = Movement.GROUND
@export_group("既有數值與技能")
## 穩定識別ID，用於存檔與技能合併；複製新種類時改成獨立ID，不要只改顯示名稱。
@export var id: StringName
## 畫面與Inspector顯示的中文名稱，不改變存檔ID。
@export var display_name: String
## 既有角色類別索引，不代替Skills清單。
@export var role: int = 0
## 基礎最大HP，实际值再套用能力、等級與裝備。
@export var max_health: float = 180.0
## 基礎最大MP，实际值再套用智力、等級與裝備。
@export var max_mana: float = 100.0
## 基礎攻擊值，也是attack公式變數的基礎来源；實際攻擊還有派生值。
@export var damage: float = 18.0
## 最終輸出傷害倍率（防禦／抵抗後），0.5代表半傷害；環境扣血不套用。
@export_range(0.0,4.0,0.05) var outgoing_damage_scale:float=1.0
## 普通攻擊射程（世界單位）。
@export var attack_range: float = 52.0
## 普通攻擊間隔秒數；不限制手動技能接收。
@export var attack_interval: float = 1.0
## 普攻前搖秒數；-1沿用遊戲設定。機關槍型召喚物可調0.025，與Attack Interval分開。
@export_range(-1.0,3.0,0.005) var attack_windup_override:float=-1.0
## 敵軍主動技能最少前搖，讓強力技能仍可被控制打斷；只對team1生效，不改玩家立即技。
@export_range(0.0,3.0,0.05) var minimum_ai_cast_time:float=0.0
## 純怪物數值更新版號；不改持久ID／等級／配怪數量。0不更新既有成員。
@export var balance_revision:int=0
## 此怪的戰術應對說明；與真實防禦、抗性、技能配搭一致，供Inspector與玩家檢視。
@export_multiline var tactical_hint:String=""
## 邏輯移動速度，單位為世界單位／秒，不是畫面像素。
@export var speed: float = 120.0
## 友軍基本索敵距離；敵方另有固定索敵節奏。
@export var detection_range: float = 260.0
## 每秒自然回復的MP。
@export var mana_regeneration: float = 1.2
## 物理抵抗比例，0.1代表10%；只套用一次。
@export var armor: float = 0.0
## 舊圖集路徑；新Sprite Layout有Source Texture時以它優先。敵我可共用同張原圖。
@export_group("角色外觀（世界／戰鬥）")
@export_file("*.png","*.webp") var sprite_path: String = ""
## 八方向與各動畫幀的切圖設定，避免自行等分造成漏圖。
@export var sprite_layout: SpriteSheetLayout
## 兵種Sprite顏色，不影響能力。
@export var sprite_tint: Color = Color.WHITE
## 戰鬥圖像基礎縮放。-1只供舊資料相容；新兵請明確填比例（常用0.4），不必靠Role決定大小。
@export_range(-1.0,4.0,0.01) var battle_sprite_scale: float=-1.0
## 世界怪隊代表圖像的縮放；不改怪隊數量、碰撞或通行。既有預設0.45。
@export_range(0.01,4.0,0.01) var world_sprite_scale: float=0.45
## 外觀體積倍率；以腳底為錨點，不改碰撞、尋路或攻擊距離。
@export_range(0.25, 4.0, 0.05) var visual_scale: float = 1.0
@export_group("獨立介面美術（非戰鬥 sprite）")
## 介面頭像PNG，與戰鬥Sprite分開。
@export_file("*.png") var portrait_path: String = ""
## 角色頁立繪PNG，與戰鬥Sprite分開。
@export_file("*.png") var standee_path: String = ""
## 可用原生AtlasTexture選SpriteSheet區域作新兵頭像；未設定時保留獨立PNG／舊圖集流程。
@export var portrait_texture: Texture2D
## 隊伍列的眼部橫幅；可用AtlasTexture裁切立繪，未設時沿用頭像。
@export var eyes_texture: Texture2D
## 可用原生AtlasTexture選完整待機姿勢作新兵立繪，不改戰鬥圖集。
@export var standee_texture: Texture2D
## 舊立繪圖集索引；獨立Portrait／Standee路徑優先。
@export_range(0,6) var illustration_index: int = 0
@export_group("技能")
## 此兵種擁有的SkillDefinition清單；拖入／移除技能資源即可配置。
@export var skills: Array[SkillDefinition] = []
@export_group("兵種語音")
## 聲音／台詞配置；缺少音訊只略過播放，不影響操作或存檔。
@export var voice_profile: UnitVoiceProfile
@export_group("選控與自主攻擊")
## false表示不能選取／下RTS指令；例如大地魔爪。怪物仍由敵人AI控制。
@export var controllable: bool = true
## 自主單位每隔0.8秒從索敵範圍隨機選敵，仍使用正常尋路與攻擊。
@export var random_nearby_target: bool = false
@export_group("死亡進化")
## 第一次致死時轉為此UnitDefinition；保持同一場內／持久ID，最終形態死亡才結算。
@export var death_evolution: Resource
## 複雜死亡階段：停場、換景、環境扣血及最終分身；與舊Death Evolution分開。
@export var death_phase:MonsterPhaseDefinition
@export_group("世界遭遇／兵種增援傾向")
## 每秒願意走近倒數戰圈的機率。-1使用怪區設定；0永不靠近，1必定嘗試（仍需合法路徑）。
@export_range(-1.0,1.0,0.01) var reinforcement_approach_chance: float = -1.0
## 走到近身位置後願意加入的機率。-1使用怪區設定；失敗會猶豫一秒後再試，不保證入場。
@export_range(-1.0,1.0,0.01) var reinforcement_join_chance: float = -1.0
