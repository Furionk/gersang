@tool
extends VBoxContainer
## Actual SpriteAtlas/SpriteFrames data, not a second slicing implementation.
var data: UnitDefinition
var texture: Texture2D
var layout: SpriteSheetLayout
var clips: SpriteFrames
var action: OptionButton
var direction: OptionButton
var frame_picker: HSlider
var detail: Label
var view: Control
var source: Control
var playing: bool=false
var elapsed: float=0
var refresh_left: float=0
var signature: String=""
var index: int=0
func _ready() -> void:
	name="ContentSpritePreview"
	var selectors: HBoxContainer=HBoxContainer.new(); add_child(selectors)
	action=OptionButton.new(); direction=OptionButton.new()
	for text: String in ["待機 idle","移動 walk","普攻 attack","施法 cast","死亡 dead"]: action.add_item(text)
	for text: String in ["右 E / 0","右下 SE / 1","下 S / 2","左下 SW / 3","左 W / 4","左上 NW / 5","上 N / 6","右上 NE / 7"]: direction.add_item(text)
	selectors.add_child(action); selectors.add_child(direction)
	action.item_selected.connect(func(_i:int)->void: reset_frame())
	direction.item_selected.connect(func(_i:int)->void: reset_frame())
	var toggle: Button=Button.new(); toggle.text="播放／暫停"; toggle.pressed.connect(func()->void: playing=not playing); add_child(toggle)
	frame_picker=HSlider.new(); frame_picker.step=1; frame_picker.value_changed.connect(func(value:float)->void: index=int(value); elapsed=0; repaint()); add_child(frame_picker)
	view=FrameCanvas.new(); view.set("owner_preview",self); view.custom_minimum_size=Vector2(240,260); add_child(view)
	source=SheetCanvas.new(); source.set("owner_preview",self); source.custom_minimum_size=Vector2(240,220); add_child(source)
	detail=Label.new(); detail.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART; add_child(detail)
	var refresh: Button=Button.new(); refresh.text="重新檢查切圖"; refresh.pressed.connect(rebuild); add_child(refresh)
	rebuild()
func animation_name() -> StringName:
	return StringName("%s_%d"%[SpriteAnimationClip.STATES[action.selected],direction.selected])
func rebuild() -> void:
	if data!=null: texture=SpriteAtlas.texture_for(data); layout=data.sprite_layout
	if texture==null:
		detail.text="沒有原圖。新Layout請拖入Source Texture；舊Layout可從兵種Inspector預覽。"; clips=null; return
	if layout!=null and not layout.valid_for(Vector2i(texture.get_size())):
		detail.text="；".join(layout.issues_for(Vector2i(texture.get_size()))); clips=null; return
	clips=SpriteAtlas.frames(texture,layout)
	signature=str(texture.get_rid())+str(layout.signature() if layout!=null else 0)
	reset_frame()
func reset_frame() -> void:
	index=0; elapsed=0; frame_picker.set_value_no_signal(0); repaint()
func repaint() -> void:
	if clips==null or not clips.has_animation(animation_name()): return
	var anim: StringName=animation_name(); var count:int=clips.get_frame_count(anim)
	frame_picker.max_value=maxi(0,count-1); index=clampi(index,0,maxi(0,count-1))
	frame_picker.set_value_no_signal(index)
	var state:String=SpriteAnimationClip.STATES[action.selected]
	var column:int=layout.columns_for(state)[index] if layout!=null else int(SpriteAtlas.PATTERNS[state][index])
	var row:int=SpriteAtlas.source_row(layout,direction.selected,state)
	var atlas:AtlasTexture=clips.get_frame_texture(anim,index) as AtlasTexture
	detail.text="畫面方向%d → 原圖列%d（0開始）%s\n%s 第%d／%d播放幀 → 來源欄%d\n裁切 %s\nFPS %.2f；此幀時間權重 %.2f\n綠十字＝接地排序點。改動畫不會改傷害／施法時間。"%[direction.selected,row,"／鏡像" if SpriteAtlas.mirrored(layout,direction.selected,state) else "",state,index+1,count,column,atlas.region,clips.get_animation_speed(anim),clips.get_frame_duration(anim,index)]
	view.queue_redraw(); source.queue_redraw()
func _process(delta:float) -> void:
	if not is_visible_in_tree() or detail==null: return
	refresh_left-=delta
	if refresh_left<=0:
		refresh_left=0.3
		var current:Texture2D=SpriteAtlas.texture_for(data) if data!=null else texture
		var active_layout:SpriteSheetLayout=data.sprite_layout if data!=null else layout
		var next:String=str(current.get_rid() if current!=null else RID())+str(active_layout.signature() if active_layout!=null else 0)
		if next!=signature: rebuild()
	if not playing or clips==null: return
	var anim:StringName=animation_name()
	elapsed+=delta
	var time:float=clips.get_frame_duration(anim,index)/clips.get_animation_speed(anim)
	var steps:int=0
	while elapsed>=time and playing and steps<64:
		steps+=1
		elapsed-=time
		if index+1>=clips.get_frame_count(anim):
			if clips.get_animation_loop(anim): index=0
			else: playing=false
		else: index+=1
		time=clips.get_frame_duration(anim,index)/clips.get_animation_speed(anim)
		repaint()

class FrameCanvas extends Control:
	var owner_preview:VBoxContainer
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.07,0.08,0.09))
		var p:VBoxContainer=owner_preview
		if p.clips==null: return
		var frame:Texture2D=p.clips.get_frame_texture(p.animation_name(),p.index)
		var canvas:Vector2=SpriteAtlas.canvas_size(p.texture,p.layout)
		var scale_value:float=minf((size.x-16)/canvas.x,(size.y-30)/canvas.y)
		var origin:Vector2=Vector2(size.x/2,size.y-25)
		draw_set_transform(origin,0,Vector2(-scale_value if SpriteAtlas.mirrored(p.layout,p.direction.selected,SpriteAnimationClip.STATES[p.action.selected]) else scale_value,scale_value))
		draw_texture(frame,-SpriteAtlas.foot(p.texture,p.layout))
		draw_set_transform(Vector2.ZERO)
		draw_line(origin-Vector2(10,0),origin+Vector2(10,0),Color.GREEN,2)
		draw_line(origin-Vector2(0,10),origin+Vector2(0,10),Color.GREEN,2)
class SheetCanvas extends Control:
	var owner_preview:VBoxContainer
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO,size),Color(0.04,0.05,0.06))
		var p:VBoxContainer=owner_preview
		if p.texture==null or p.clips==null: return
		var ratio:float=minf(size.x/p.texture.get_width(),size.y/p.texture.get_height())
		var extent:Vector2=p.texture.get_size()*ratio
		var origin:Vector2=(size-extent)/2
		draw_texture_rect(p.texture,Rect2(origin,extent),false)
		var frame:AtlasTexture=p.clips.get_frame_texture(p.animation_name(),p.index) as AtlasTexture
		draw_rect(Rect2(origin+frame.region.position*ratio,frame.region.size*ratio),Color.YELLOW,false,2)
