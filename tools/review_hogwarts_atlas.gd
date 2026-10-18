extends SceneTree
## Initial metadata repair only. Original PNG pixels are NEVER edited.
const IDS:Array[String]=["school_dementor","school_dark_elf","school_gatekeeper","school_basilisk","school_cerberus","voldemort_illusion","ganondorf_phantom"]
func _initialize()->void:call_deferred("run")
func silhouette(image:Image)->Rect2i:
	image.convert(Image.FORMAT_RGBA8)
	var raw:PackedByteArray=image.get_data();var w:int=image.get_width();var h:int=image.get_height()
	var visited:PackedByteArray=PackedByteArray();visited.resize(w*h)
	var pieces:Array[Dictionary]=[]
	for start:int in w*h:
		if visited[start]>0 or raw[start*4+3]<32:continue
		var queue:PackedInt32Array=PackedInt32Array([start]);var read:int=0;visited[start]=1
		var min_x:int=start%w;var max_x:int=min_x;var min_y:int=start/w;var max_y:int=min_y
		while read<queue.size():
			var index:int=queue[read];read+=1;var x:int=index%w;var y:int=index/w
			min_x=mini(min_x,x);max_x=maxi(max_x,x);min_y=mini(min_y,y);max_y=maxi(max_y,y)
			for offset:Vector2i in [Vector2i(1,0),Vector2i(-1,0),Vector2i(0,1),Vector2i(0,-1)]:
				var next:Vector2i=Vector2i(x,y)+offset
				if next.x<0 or next.y<0 or next.x>=w or next.y>=h:continue
				var n:int=next.y*w+next.x
				if visited[n]>0 or raw[n*4+3]<32:continue
				visited[n]=1;queue.append(n)
		if queue.size()>=5:pieces.append({"size":queue.size(),"rect":Rect2i(min_x,min_y,max_x-min_x+1,max_y-min_y+1)})
	if pieces.is_empty():return image.get_used_rect()
	pieces.sort_custom(func(a:Dictionary,b:Dictionary)->bool:return a.size>b.size)
	var result:Rect2i=pieces[0].rect
	for piece:Dictionary in pieces:
		if piece.rect.intersects(result.grow(14)):result=result.merge(piece.rect)
	return result.grow(2).intersection(Rect2i(0,0,w,h))
func run()->void:
	for id:String in IDS:
		var layout:SpriteSheetLayout=load("res://features/units/data/layouts/"+id+"_layout.tres")
		if layout.has_meta("initial_silhouette_review"):push_error("Atlas already reviewed; refuses overwrite "+id);quit(1);return
		var image:Image=layout.source_texture.get_image();var crops:Array[Rect2i]=[]
		for row:int in 8:
			for col:int in 6:
				var a:Vector2i=Vector2i(col*image.get_width()/6,row*image.get_height()/8);var b:Vector2i=Vector2i((col+1)*image.get_width()/6,(row+1)*image.get_height()/8)
				var crop:Rect2i=silhouette(image.get_region(Rect2i(a,b-a)));crops.append(Rect2i(a+crop.position,crop.size))
		layout.frame_rects=crops
		for row:int in 8:
			# Use the idle anatomical contact point for all live poses, not spark tips.
			var idle:Rect2i=crops[row*6];var foot:Vector2=Vector2(idle.position)+Vector2(idle.size.x*0.5,idle.size.y-2)
			for col:int in 6:
				var rect:Rect2i=crops[row*6+col];var pivot:Vector2=foot+Vector2(col*image.get_width()/6,0)-Vector2(rect.position)
				if col==5:pivot=Vector2(rect.size.x*0.5,rect.size.y-2)
				layout.source_pivots[row*6+col]=pivot
		if id=="school_cerberus":layout.direction_rows.assign([2,1,0,7,6,5,4,3])
		layout.set_meta("initial_silhouette_review",true);assert(layout.valid_for(image.get_size()))
		assert(ResourceSaver.save(layout,layout.resource_path)==OK)
	# Unique actions for separately editable enemy skills; no player binding changes.
	for id:String in ["school_red_charge","illusion_avada","blood_moon_wave"]:
		var skill:SkillDefinition=load("res://features/skills/data/"+id+".tres");skill.action=StringName("skill_"+id)
		if id=="illusion_avada":skill.description="0.5秒施法；原Avada最大HP比例公式的25%，法抗照常。"
		assert(ResourceSaver.save(skill,skill.resource_path)==OK)
	print("HOGWARTS_ATLASES_REVIEWED original_PNGs_unchanged 7 native crops");quit()
