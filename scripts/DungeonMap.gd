extends CanvasLayer
## Full-screen dungeon map — M key. Shows exact room placement from tree data.

const CELL: int = 40
const GAP: int = 6

var _room_data: Dictionary = {}
var _current_room: String = ""
var _entrance_room: String = ""
var _draw_ctrl: Control = null
var _cycle_links: Array = []
var _pulse: float = 0.0
var _compass_tex: Texture2D = null

const COLORS: Array = [
	Color("#8B7500"), Color("#1A6B3A"), Color("#1A4D8F"),
	Color("#888888"), Color("#6B1A8F"), Color("#8F3D1A"),
	Color("#555555"), Color("#B8860B"), Color("#8B1A1A"), Color("#1A6B6B"),
]


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false
	layer = 90
	_draw_ctrl = Control.new()
	_draw_ctrl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_draw_ctrl.set_anchors_preset(Control.PRESET_FULL_RECT)
	_draw_ctrl.draw.connect(_on_draw)
	_compass_tex = load("res://textures/ui/north.png") as Texture2D
	add_child(_draw_ctrl)


func open(rooms: Dictionary, cycle_links: Array, current: String, entrance: String) -> void:
	_room_data.clear()
	for rid in rooms.keys():
		var rs: Dictionary = rooms[rid]
		var data := {
			"template": rs.get("template", 0),
			"parent": rs.get("parent", ""),
			"exits": rs.get("exits", []),
		}
		_room_data[rid] = data
	_current_room = current
	_entrance_room = entrance
	_cycle_links = cycle_links if cycle_links else []
	visible = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true
	if _draw_ctrl: _draw_ctrl.queue_redraw()


func close() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if visible and ((event is InputEventKey and event.keycode == KEY_M and event.pressed) or event.is_action_pressed("ui_cancel")):
		close()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if visible:
		_pulse += delta * 3.0
		if _draw_ctrl: _draw_ctrl.queue_redraw()


func _on_draw() -> void:
	if _room_data.is_empty(): return

	# Compute positions by walking the tree from the entrance
	var positions: Dictionary = {}
	_compute_positions(positions)

	# Find bounds
	var min_x := 999; var max_x := -999; var min_y := 999; var max_y := -999
	for p in positions.values():
		var pv: Vector2i = p as Vector2i
		min_x = min(min_x, pv.x); max_x = max(max_x, pv.x)
		min_y = min(min_y, pv.y); max_y = max(max_y, pv.y)

	var vs := get_viewport().get_visible_rect().size
	var map_w := (max_x - min_x + 1) * (CELL + GAP) + GAP
	var map_h := (max_y - min_y + 1) * (CELL + GAP) + GAP
	var off := Vector2((vs.x - map_w) / 2.0, (vs.y - map_h) / 2.0)

	# Background
	_draw_ctrl.draw_rect(Rect2(off.x - 10, off.y - 10, map_w + 20, map_h + 20), Color(0, 0, 0, 0.85), true)
	_draw_ctrl.draw_rect(Rect2(off.x - 10, off.y - 10, map_w + 20, map_h + 20), Color(1, 1, 1, 0.2), false, 2.0)

	# Connections
	for rid in positions.keys():
		var data: Dictionary = _room_data.get(rid, {})
		var pid: String = data.get("parent", "")
		if pid != "" and positions.has(pid):
			var fc := _cell_center(positions[pid], off, min_x, min_y)
			var tc := _cell_center(positions[rid], off, min_x, min_y)
			_draw_ctrl.draw_line(fc, tc, Color(1, 1, 1, 0.4), 3.0, true)

	# One-way cycle connections (hidden passages)
		for link in _cycle_links:
			var lk: Dictionary = link as Dictionary
			var from_id: String = lk.get("from", "")
			var to_id: String = lk.get("to", "")
			if positions.has(from_id) and positions.has(to_id):
				var fc := _cell_center(positions[from_id], off, min_x, min_y)
				var tc := _cell_center(positions[to_id], off, min_x, min_y)
				_draw_ctrl.draw_line(fc, tc, Color(1.0, 0.55, 0.0, 0.7), 2.0, true)

		# Rooms
	for rid in positions.keys():
		var pos: Vector2i = positions[rid]
		var data: Dictionary = _room_data.get(rid, {})
		var tpl: int = data.get("template", 0)
		var col: Color = COLORS[tpl % COLORS.size()]
		if rid == _current_room:
			col = Color.WHITE
		var r := _cell_rect(pos, off, min_x, min_y)
		_draw_ctrl.draw_rect(r, col, true)
		if rid == _current_room:
			var pv: float = abs(sin(_pulse))
			var pr := Rect2(r.position.x - 3 * pv, r.position.y - 3 * pv, r.size.x + 6 * pv, r.size.y + 6 * pv)
			_draw_ctrl.draw_rect(pr, Color(1.0, 1.0, 1.0, 0.3 + 0.5 * pv), false, 2.0 + pv)
		if rid == _entrance_room:
			_draw_ctrl.draw_rect(r, Color.YELLOW, false, 3.0)
		# Room label
		var label := "R%d" % tpl
		_draw_ctrl.draw_string(ThemeDB.fallback_font, r.position + Vector2(4, 26), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color.BLACK)
			# Compass rose
		if _compass_tex:
			_draw_ctrl.draw_texture_rect(_compass_tex, Rect2(vs.x - 70, 8, 60, 60), false)

func _compute_positions(positions: Dictionary) -> void:
	# BFS from entrance room
	var queue: Array = [_entrance_room]
	positions[_entrance_room] = Vector2i.ZERO
	while queue.size() > 0:
		var rid: String = queue.pop_front()
		var parent_pos: Vector2i = positions[rid]
		var data: Dictionary = _room_data.get(rid, {})
		for ex in data.get("exits", []):
			var ed: Dictionary = ex as Dictionary
			var target: String = ed.get("linked", "")
			if target == "" or positions.has(target):
				continue
			var dr: String = ed.get("dir", "")
			var entry: String = Globals.room_entry_dirs.get(rid, "")
			var gdr: String = dr
			if entry == "east":
				match dr:
					"north": gdr = "east"
					"east": gdr = "south"
					"south": gdr = "west"
					"west": gdr = "north"
			elif entry == "west":
				match dr:
					"north": gdr = "west"
					"west": gdr = "south"
					"south": gdr = "east"
					"east": gdr = "north"
			elif entry == "south":
				match dr: 
					"north": gdr = "south"; 
					"west": gdr = "east"; 
					"south": gdr = "north"; 
					"east": gdr = "west"
			var off := Vector2i.ZERO
			match gdr:
				"north": off = Vector2i(0, -1)
				"south": off = Vector2i(0, 1)
				"east":  off = Vector2i(1, 0)
				"west":  off = Vector2i(-1, 0)
			var new_pos := parent_pos + off
			positions[target] = new_pos
			queue.append(target)


func _cell_rect(pos: Vector2i, off: Vector2, min_x: int, min_y: int) -> Rect2:
	return Rect2(off.x + (pos.x - min_x) * (CELL + GAP) + GAP, off.y + (pos.y - min_y) * (CELL + GAP) + GAP, CELL, CELL)


func _cell_center(pos: Vector2i, off: Vector2, min_x: int, min_y: int) -> Vector2:
	var r := _cell_rect(pos, off, min_x, min_y)
	return r.position + r.size * 0.5
