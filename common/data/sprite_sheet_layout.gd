@tool
class_name SpriteSheetLayout
extends Resource
## Original PNG stays immutable; each source frame and its foot pivot are authored.
@export_group("原圖與裁切")
## 新素材推薦直接拖入Texture；設定後優先於兵種的舊Sprite Path。
@export var source_texture: Texture2D
## 原PNG的實際像素尺寸，不是單格尺寸。
@export var source_size: Vector2i = Vector2i(1086,1448)
## 來源每列有多少個可選姿勢。不限6欄；不能只改數量而不補齊Rects/Pivots。
@export var columns: int = 6
## 來源有多少方向列。可少於8列，Direction Rows可重用來源列配合鏡像。
@export var rows: int = 8
## 每幀呈現用的共同透明畫布；須容納所有裁切，讓腳底保持一致。
@export var frame_size: Vector2i = Vector2i(224,224)
## 共同畫布上的接地位置；不改邏輯碰撞。
@export var foot_point: Vector2 = Vector2(112,198)
## Rects按「來源列×Columns＋來源欄」排列；可使用不規則矩形，不必等分PNG。
@export var frame_rects: Array[Rect2i] = []
## 每個裁切內的腳底像素，相對於該Rect左上；數量須與Rects相同。
@export var source_pivots: Array[Vector2] = []
@export_group("動作（可變幀數）")
## 新增SpriteAnimationClip分別配置待機／移動／普攻／施法／死亡。未覆蓋的動作保留舊規則。
@export var animations: Array[SpriteAnimationClip]=[]
@export_group("舊普攻相容（無自訂普攻時使用）")
## 普攻動畫依序播放哪些欄（0開始）；魔爪使用抬爪→刺地→收爪。
@export var attack_columns: Array[int] = [3,0]
## 普攻動畫每秒幀數，僅呈現，不改傷害或攻擊間隔。
@export var attack_fps: float = 3.0
@export_group("八方向對應（畫面方向）")
## Output compass rows E, SE, S, SW, W, NW, N, NE; art may need remap/mirror.
@export var direction_rows: Array[int] = [0,1,2,3,4,5,6,7]
@export var mirrored_directions: Array[bool] = [false,false,false,false,false,false,false,false]
func clip_for(state: String) -> SpriteAnimationClip:
	for clip: SpriteAnimationClip in animations:
		if clip!=null and clip.state_name()==state: return clip
	return null
func columns_for(state: String) -> PackedInt32Array:
	var clip: SpriteAnimationClip=clip_for(state)
	if clip!=null: return clip.columns
	if state=="attack": return PackedInt32Array(attack_columns)
	return PackedInt32Array({"idle":[0,0],"walk":[1,2],"cast":[4,0],"dead":[5]}.get(state,[]))
func fps_for(state: String) -> float:
	var clip: SpriteAnimationClip=clip_for(state)
	return clip.fps if clip!=null else attack_fps if state=="attack" else 6.0 if state=="walk" else 3.0
func loop_for(state: String) -> bool:
	var clip: SpriteAnimationClip=clip_for(state)
	return clip.loop if clip!=null else state in ["idle","walk"]
func duration_for(state: String,index: int) -> float:
	var clip: SpriteAnimationClip=clip_for(state)
	return clip.frame_durations[index] if clip!=null and not clip.frame_durations.is_empty() else 1.0
func row_for(state: String,direction: int) -> int:
	var clip: SpriteAnimationClip=clip_for(state)
	return clip.direction_rows[direction] if clip!=null and clip.direction_rows.size()==8 else direction_rows[direction]
func mirror_for(state: String,direction: int) -> bool:
	var clip: SpriteAnimationClip=clip_for(state)
	return clip.mirrored_directions[direction] if clip!=null and clip.mirrored_directions.size()==8 else mirrored_directions[direction]
func signature() -> int:
	var values: Array=[source_size,columns,rows,frame_rects,source_pivots,frame_size,foot_point,direction_rows,mirrored_directions,attack_columns,attack_fps]
	for clip: SpriteAnimationClip in animations:
		values.append(null if clip==null else [clip.action,clip.columns,clip.fps,clip.loop,clip.frame_durations,clip.instant_start_frame,clip.direction_rows,clip.mirrored_directions])
	return values.hash()
func issues_for(texture_size: Vector2i) -> PackedStringArray:
	var result: PackedStringArray=PackedStringArray()
	if columns<=0 or rows<=0 or frame_size.x<=0 or frame_size.y<=0: result.append("來源欄列數及共同畫布尺寸必須大於0。")
	if direction_rows.size()!=8 or mirrored_directions.size()!=8: result.append("畫面八方向對應與鏡像各需8項。")
	for row: int in direction_rows:
		if row<0 or row>=rows: result.append("方向引用了不存在的來源列%d。"%row)
	if texture_size!=source_size: result.append("Source Size與原圖實際尺寸不一致。")
	if frame_rects.size()!=columns*rows or source_pivots.size()!=frame_rects.size(): result.append("Rects數量須等於Columns×Rows，Pivots須與Rects相同。")
	var seen: Dictionary={}
	for clip: SpriteAnimationClip in animations:
		if clip==null: result.append("Animations有空資源。"); continue
		if seen.has(clip.state_name()): result.append("動作重複："+clip.state_name())
		seen[clip.state_name()]=true
		result.append_array(clip.issues(columns))
		for row: int in clip.direction_rows:
			if row<0 or row>=rows: result.append("動作方向引用了不存在的來源列%d。"%row)
	for state: String in SpriteAnimationClip.STATES:
		if columns_for(state).is_empty() or not is_finite(fps_for(state)) or fps_for(state)<=0: result.append(state+"沒有有效播放幀／FPS。")
		for column: int in columns_for(state):
			if column<0 or column>=columns: result.append(state+"引用來源欄%d；請配置此動作Clip。"%column)
	if not foot_point.is_finite(): result.append("Foot Point須為有限數值。")
	for pivot: Vector2 in source_pivots:
		if not pivot.is_finite(): result.append("Source Pivot須為有限數值。")
	var bounds: Rect2i = Rect2i(Vector2i.ZERO,source_size)
	for rect: Rect2i in frame_rects:
		if rect.size.x<=0 or rect.size.y<=0 or not bounds.encloses(rect) or rect.size.x>frame_size.x or rect.size.y>frame_size.y: result.append("裁切為空／超出原PNG／大於共同畫布。")
	return result
func valid_for(texture_size: Vector2i) -> bool:
	return issues_for(texture_size).is_empty()
func regular_grid_values(texture_size:Vector2i) -> Dictionary:
	# Author initialization only. Does not mutate existing crops or a PNG.
	if columns<=0 or rows<=0 or columns>texture_size.x or rows>texture_size.y or columns*rows>8192: return {}
	var rects:Array[Rect2i]=[]; var pivots:Array[Vector2]=[]
	var canvas:Vector2i=Vector2i(ceili(float(texture_size.x)/columns),ceili(float(texture_size.y)/rows))
	for row:int in rows:
		for column:int in columns:
			var start:Vector2i=Vector2i(int(float(column)*texture_size.x/columns),int(float(row)*texture_size.y/rows))
			var end:Vector2i=Vector2i(int(float(column+1)*texture_size.x/columns),int(float(row+1)*texture_size.y/rows))
			rects.append(Rect2i(start,end-start)); pivots.append(Vector2((end.x-start.x)*0.5,(end.y-start.y)*0.87))
	return {"source_size":texture_size,"frame_size":canvas,"foot_point":Vector2(canvas.x*0.5,canvas.y*0.87),"frame_rects":rects,"source_pivots":pivots}
