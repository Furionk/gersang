@tool
class_name AtlasSilhouetteBounds
extends RefCounted
## Read-only source analysis for native Atlas rectangles. Never rewrites the PNG.
static func meaningful(image: Image, primary_only: bool = false) -> Rect2i:
	var size: Vector2i=image.get_size()
	var seen: PackedByteArray=[]; seen.resize(size.x*size.y)
	var components: Array[Dictionary]=[]; var largest: int=0
	for y: int in size.y:
		for x: int in size.x:
			var index: int=y*size.x+x
			if seen[index]!=0 or image.get_pixel(x,y).a<0.12: continue
			var pending: Array[Vector2i]=[Vector2i(x,y)]; seen[index]=1
			var bounds: Rect2i=Rect2i(Vector2i(x,y),Vector2i.ONE); var area: int=0
			while not pending.is_empty():
				var at: Vector2i=pending.pop_back(); area+=1; bounds=bounds.merge(Rect2i(at,Vector2i.ONE))
				for direction: Vector2i in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
					var next: Vector2i=at+direction
					if next.x<0 or next.y<0 or next.x>=size.x or next.y>=size.y: continue
					var next_index: int=next.y*size.x+next.x
					if seen[next_index]!=0: continue
					seen[next_index]=1
					if image.get_pixelv(next).a>=0.12: pending.append(next)
			components.append({"area":area,"bounds":bounds}); largest=maxi(largest,area)
	var result: Rect2i
	for component: Dictionary in components:
		if primary_only and component.area != largest: continue
		if component.area<maxi(64,int(largest*0.01)): continue
		result=component.bounds if result.size==Vector2i.ZERO else result.merge(component.bounds)
	return result.grow(2).intersection(Rect2i(Vector2i.ZERO,size))
