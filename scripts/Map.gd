extends Node2D

@onready var tileMap = $MapCreator

var floor_cells : Array[Vector2i] = []
var door_cells : Dictionary = {}
var hallway_cells : Array[Vector2i] = []
var generated_rooms : Array[Dictionary] = []

const ROOM_COUNT := 14
const ROOM_SPACING := 7

var ROOM_SHAPES : Array = [
	{"shape": [[0,0],[1,0],[2,0],[3,0],[0,1],[1,1],[2,1],[3,1],[0,2],[1,2],[2,2],[3,2],[0,3],[1,3],[2,3],[3,3]], "width":4, "height":4},
	{"shape": [[0,0],[1,0],[2,0],[3,0],[4,0],[0,1],[1,1],[2,1],[3,1],[4,1],[1,2],[2,2],[3,2]], "width":5, "height":3},
	{"shape": [[0,0],[1,0],[2,0],[3,0],[4,0],[0,1],[1,1],[2,1],[3,1],[4,1],[2,2]], "width":5, "height":3},
	{"shape": [[0,0],[1,0],[2,0],[3,0],[4,0],[0,1],[1,1],[2,1],[3,1],[4,1],[3,2]], "width":5, "height":3},
	{"shape": [[0,0],[1,0],[0,1],[1,1],[2,1],[0,2],[1,2],[2,2],[1,3]], "width":3, "height":4},
	{"shape": [[0,0],[1,0],[2,0],[0,1],[1,1],[2,1],[0,2],[1,2],[2,2],[1,3]], "width":3, "height":4},
	{"shape": [[0,0],[1,0],[0,1],[1,1],[0,2],[1,2],[0,3],[1,3],[2,3],[3,3]], "width":4, "height":4},
	{"shape": [[0,0],[1,0],[2,0],[3,0],[4,0],[2,1],[2,2]], "width":5, "height":3},
	{"shape": [[1,0],[0,1],[1,1],[2,1],[1,2]], "width":3, "height":3},
	{"shape": [[0,0],[1,0],[1,1],[2,1],[2,2],[3,2]], "width":4, "height":3},
	{"shape": [[0,0],[2,0],[0,1],[2,1],[0,2],[1,2],[2,2]], "width":3, "height":3},
	{"shape": [[0,0],[0,1],[0,2],[0,3],[0,4]], "width":1, "height":5}
]

var entrance_room : Dictionary

func _ready(): pass  # Generation handled by RoomGenerator in World.gd
func get_floor_cells(): return floor_cells
func get_door_cells(): return door_cells
func get_hallway_cells(): return hallway_cells
#func get_rooms(): return generated_rooms.duplicate(true)

func generate_level():
	floor_cells.clear(); door_cells.clear(); hallway_cells.clear(); generated_rooms.clear()
	var rooms : Array[Dictionary] = []
	var entrance_shape = ROOM_SHAPES[0]
	entrance_room = {"position":Vector2i.ZERO,"shape":entrance_shape.shape,"width":entrance_shape.width,"height":entrance_shape.height}
	entrance_room["tiles"] = build_room_tiles(entrance_room)
	entrance_room["center"] = room_center(entrance_room)
	rooms.append(entrance_room)
	add_room_tiles(entrance_room, floor_cells)

	for i in range(ROOM_COUNT):
		var parent_room = rooms.pick_random()
		var direction = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT].pick_random()
		var shape_index = randi_range(1, ROOM_SHAPES.size() - 1)
		var room_shape = ROOM_SHAPES[shape_index]
		var room_position = parent_room.position + direction * ROOM_SPACING
		var new_room = {"position":room_position,"shape":room_shape.shape,"width":room_shape.width,"height":room_shape.height}
		if room_overlaps(new_room, rooms): continue
		new_room["tiles"] = build_room_tiles(new_room)
		new_room["center"] = room_center(new_room)
		rooms.append(new_room)
		add_room_tiles(new_room, floor_cells)
		if check_adjacent_rooms(parent_room, new_room):
			create_doorway(parent_room, new_room, floor_cells, door_cells)
		else:
			connect_rooms(parent_room, new_room, floor_cells, door_cells)

	tileMap.clear()
	tileMap.set_cells_terrain_connect(0, floor_cells, 0, 0)
	print("Rooms: ", rooms.size(), "  Doors: ", door_cells.size())
	generated_rooms = rooms.duplicate(true)

func add_room_tiles(room, cells):
	for tile in build_room_tiles(room):
		if tile not in cells: cells.append(tile)

func build_room_tiles(room) -> Array[Vector2i]:
	var tiles : Array[Vector2i] = []
	for t in room.shape: tiles.append(room.position + Vector2i(t[0], t[1]))
	return tiles

func room_overlaps(room, rooms) -> bool:
	var nr = build_room_tiles(room); var buf : Array[Vector2i] = []
	for t in nr: buf.append(t); buf.append(t+Vector2i(1,0)); buf.append(t+Vector2i(-1,0)); buf.append(t+Vector2i(0,1)); buf.append(t+Vector2i(0,-1))
	for o in rooms:
		for b in buf:
			if b in o["tiles"]: return true
	return false

func room_center(room) -> Vector2i:
	var tx:int=0; var ty:int=0; var tc:int=room.shape.size()
	for t in room.shape: tx+=t[0]; ty+=t[1]
	return room.position + Vector2i(tx/tc, ty/tc)

func check_adjacent_rooms(room_a, room_b) -> bool:
	for ta in room_a["tiles"]: for tb in room_b["tiles"]: if ta.distance_to(tb)==1: return true
	return false

func create_doorway(room_a, room_b, floor_tiles, door_tiles):
	var ra:Array=room_a["tiles"]; var rb:Array=room_b["tiles"]; var cand:Array[Vector2i]=[]
	for tb in rb: for ta in ra: if ta.distance_to(tb)==1: cand.append(tb); break
	var ca:Vector2i=room_a["center"]; var dp:Vector2i=cand[0]
	for c in cand: if c.distance_squared_to(ca)<dp.distance_squared_to(ca): dp=c
	var rot:int=0; var off:Vector2i=Vector2i.ZERO
	for ta in ra:
		if ta.distance_to(dp)==1:
			if abs(ta.x-dp.x)==1: rot=90; off=Vector2i(sign(ta.x-dp.x),0)
			else: rot=0; off=Vector2i(0,sign(ta.y-dp.y))
			break
	if dp not in floor_tiles: floor_tiles.append(dp)
	if dp not in door_tiles: door_tiles[dp]={"rotation":rot,"offset":off}

func get_room_edge(room, target) -> Vector2i:
	var tiles:Array=room.get("tiles",[]); if tiles.is_empty(): return room.get("position",Vector2i.ZERO)
	var bt:Vector2i=tiles[0]; var bd:int=bt.distance_squared_to(target)
	for i in range(1,tiles.size()): var t:Vector2i=tiles[i]; var d:int=t.distance_squared_to(target); if d<bd: bd=d; bt=t
	return bt

func connect_rooms(room_a, room_b, floor_tiles, door_tiles):
	var ca:Vector2i=room_a["center"]; var cb:Vector2i=room_b["center"]
	var da=get_room_edge(room_a,cb); var db=get_room_edge(room_b,ca)
	var dd:Vector2i=db-da; var hf:bool=abs(dd.x)>=abs(dd.y); var ls:bool=da.x!=db.x and da.y!=db.y
	if ls:
		var bst:Vector2i=db; var bd:int=999999
		for t in room_b["tiles"]: if t.x==da.x or t.y==da.y: var d:int=abs(t.x-da.x)+abs(t.y-da.y); if d<bd: bd=d; bst=t
		if bd<999999: db=bst; dd=db-da; hf=abs(dd.x)>=abs(dd.y)
	var rot:int=90 if hf else 0; var oa:Vector2i
	if hf: 
		oa=Vector2i(sign(dd.x),0) 
	else: 
		oa=Vector2i(0,sign(dd.y))
	var ob:Vector2i=Vector2i(-oa.x,-oa.y)
	if da not in door_tiles: door_tiles[da]={"rotation":rot,"offset":oa}
	if db not in door_tiles: door_tiles[db]={"rotation":rot,"offset":ob}
	print("  -> doors: %s and %s" % [da, db])
	create_hallway(da, db, floor_tiles, hf)

func create_hallway(start_pos:Vector2i, end_pos:Vector2i, floor_tiles, horizontal_first:bool):
	var cur=start_pos; var tiles:Array[Vector2i]=[]
	if horizontal_first:
		cur.x+=sign(end_pos.x-cur.x)
		while cur.x!=end_pos.x: tiles.append(cur); cur.x+=sign(end_pos.x-cur.x)
		while cur.y!=end_pos.y: tiles.append(cur); cur.y+=sign(end_pos.y-cur.y)
	else:
		cur.y+=sign(end_pos.y-cur.y)
		while cur.y!=end_pos.y: tiles.append(cur); cur.y+=sign(end_pos.y-cur.y)
		while cur.x!=end_pos.x: tiles.append(cur); cur.x+=sign(end_pos.x-cur.x)
	for tile in tiles: if tile not in floor_tiles: floor_tiles.append(tile); hallway_cells.append(tile)
	if start_pos not in floor_tiles: floor_tiles.append(start_pos)
	if end_pos not in floor_tiles: floor_tiles.append(end_pos)

func get_rooms() -> Array: return generated_rooms.duplicate(true)
func reload_level(): get_tree().reload_current_scene()
func get_tilemap(): return tileMap
func _input(event): if event.is_action_pressed("enter"): reload_level()
