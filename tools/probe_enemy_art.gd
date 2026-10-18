extends SceneTree
func _initialize() -> void:
	for path: String in OS.get_cmdline_user_args():
		var image: Image = Image.load_from_file(path)
		var lo: float = 1.0
		var hi: float = 0.0
		for y: int in range(0,image.get_height(),12):
			for x: int in range(0,image.get_width(),12):
				var a: float = image.get_pixel(x,y).a
				lo = minf(lo,a); hi = maxf(hi,a)
		print("IMAGE_ALPHA ",path," size=",image.get_size()," min=",lo," max=",hi," corner=",image.get_pixel(0,0))
	quit()
