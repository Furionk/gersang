class_name PuzzleBoard
extends RefCounted
const WIDTH: int = 6
const HEIGHT: int = 5
const TYPES: int = 5
var cells: Array[int] = []
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

func initialize(seed_value: int) -> void:
	rng.seed = seed_value
	cells.resize(WIDTH * HEIGHT)
	for attempt: int in 100:
		for i: int in cells.size():
			var choices: Array[int] = [0,1,2,3,4]
			if i % WIDTH >= 2 and cells[i-1] == cells[i-2]: choices.erase(cells[i-1])
			if i >= WIDTH*2 and cells[i-WIDTH] == cells[i-WIDTH*2]: choices.erase(cells[i-WIDTH])
			cells[i] = choices[rng.randi_range(0,choices.size()-1)]
		if has_move(): return
	# Deterministic valid fallback, with one adjacent swap creating a match.
	cells.assign([0,1,0,2,3,4, 1,0,2,3,4,0, 2,3,4,0,1,2, 3,4,0,1,2,3, 4,0,1,2,3,4])

func swap(a: int, b: int) -> void:
	var old: int = cells[a]
	cells[a] = cells[b]
	cells[b] = old

func path_between(a: int, b: int) -> Array[int]:
	var path: Array[int] = []
	var at: Vector2i = Vector2i(a % WIDTH, a / WIDTH)
	var end: Vector2i = Vector2i(b % WIDTH, b / WIDTH)
	# Horizontal then vertical is deterministic even for a skipped mouse event.
	while at != end:
		if at.x != end.x: at.x += signi(end.x-at.x)
		else: at.y += signi(end.y-at.y)
		path.append(at.y*WIDTH+at.x)
	return path

func matches() -> Array[Dictionary]:
	var marked: Dictionary = {}
	for i: int in cells.size():
		if cells[i] < 0: continue
		if i % WIDTH <= WIDTH-3 and cells[i] == cells[i+1] and cells[i] == cells[i+2]:
			for n: int in 3: marked[i+n] = true
		if i / WIDTH < HEIGHT-2 and cells[i] == cells[i+WIDTH] and cells[i] == cells[i+WIDTH*2]:
			for n: int in 3: marked[i+n*WIDTH] = true
	var groups: Array[Dictionary] = []
	while not marked.is_empty():
		var start: int = marked.keys()[0]
		var group: Array[int] = []
		var pending: Array[int] = [start]
		marked.erase(start)
		while not pending.is_empty():
			var current: int = pending.pop_back()
			group.append(current)
			for neighbor: int in neighbors(current):
				if marked.has(neighbor) and cells[neighbor] == cells[start]:
					marked.erase(neighbor)
					pending.append(neighbor)
		groups.append({"element":cells[start],"cells":group,"count":group.size()})
	return groups

func neighbors(i: int) -> Array[int]:
	var result: Array[int] = []
	if i % WIDTH > 0: result.append(i-1)
	if i % WIDTH < WIDTH-1: result.append(i+1)
	if i >= WIDTH: result.append(i-WIDTH)
	if i < WIDTH*(HEIGHT-1): result.append(i+WIDTH)
	return result

func has_move() -> bool:
	for a: int in cells.size():
		for b: int in neighbors(a):
			if b <= a: continue
			swap(a,b)
			var found: bool = not matches().is_empty()
			swap(a,b)
			if found: return true
	return false

func clear_groups(groups: Array[Dictionary]) -> void:
	for group: Dictionary in groups:
		for i: int in group.cells: cells[i] = -1

func refill() -> void:
	for x: int in WIDTH:
		var write_y: int = HEIGHT-1
		for y: int in range(HEIGHT-1,-1,-1):
			if cells[y*WIDTH+x] >= 0:
				cells[write_y*WIDTH+x] = cells[y*WIDTH+x]
				write_y -= 1
		while write_y >= 0:
			cells[write_y*WIDTH+x] = rng.randi_range(0,TYPES-1)
			write_y -= 1
