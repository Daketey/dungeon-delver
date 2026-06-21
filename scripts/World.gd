extends Node3D

const CellScene = preload("res://scenes/Cell.tscn")
const DoorScene = preload("res://scenes/Door.tscn")
const Player = preload("res://scenes/Player.tscn")
const Merchant = preload("res://scenes/Merchant.tscn")
const EnemyPlaceholder = preload("res://scenes/EnemyPlaceholder.tscn")
const TrapPlaceholder = preload("res://scenes/TrapPlaceholder.tscn")
const CombatManager = preload("res://scripts/CombatManager.gd")
const CombatScreenScene = preload("res://scenes/CombatScreen.tscn")
const PlayerHUD = preload("res://scenes/PlayerHUD.tscn")
const InventoryScreenScene = preload("res://scenes/InventoryScreen.tscn")
const ShopScreenScene = preload("res://scenes/ShopScreen.tscn")
const RoomGenerator = preload("res://scripts/RoomGenerator.gd")
const DiceOverlayScene = preload("res://scenes/DiceOverlay.tscn")
const PuzzleScreenScene = preload("res://scenes/PuzzleScreen.tscn")
const PuzzlePedestalScene = preload("res://scenes/PuzzlePedestal.tscn")
const RuneMemoryScreenScene = preload("res://scenes/RuneMemoryScreen.tscn")
const MobileControlsScene = preload("res://scenes/MobileControls.tscn")

var combat_screen: CombatScreen = null
var inventory_screen: CanvasLayer = null
var shop_screen: CanvasLayer = null
var _pedestal: PuzzlePedestal = null
var _pending_trap: Dictionary = {}
var _pending_spring: Dictionary = {}
var _hud: CanvasLayer = null
var _map_screen: CanvasLayer = null
var _fade: ColorRect = null
var _transitioning: bool = false

# Dungeon state
var _rooms: Dictionary = {}
var _door_pairs: Dictionary = {}
var _next_room_id: int = 0
var _current_room_id: String = ""
var _entrance_room_id: String = ""
var _current_exits: Array = []
var _current_entrance: Vector2i = Vector2i.ZERO
var _room_enter_time: float = 0.0
var _boss_distance: int = -1
var _boss_room_id: String = ""
var _last_template: int = -1
var _cycle_links: Array = []  # [{from, to}] one-way hidden passages
var _debug_no_spawn: bool = false  # Toggle with F1 to disable enemy spawns
var _current_tint: Color = Color.WHITE
var _total_max_kills : int = 10


func _ready() -> void:
	# Mobile platform setup
	if _on_mobile():
		var mc := MobileControlsScene.instantiate()
		mc.name = "MobileControls"
		add_child(mc)
		mc.interact_pressed.connect(_on_mobile_interact)
		mc.inventory_pressed.connect(_on_mobile_inventory)
		mc.map_pressed.connect(_on_mobile_map)

	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.modulate = Color(1, 1, 1, 0)
	_fade.size = Vector2(4096, 4096)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fade)

	var cm: CombatManager = CombatManager.new(); cm.name = "CombatManager"; add_child(cm)

	combat_screen = CombatScreenScene.instantiate() as CombatScreen
	combat_screen.name = "CombatScreen"; combat_screen.visible = false; add_child(combat_screen)

	inventory_screen = InventoryScreenScene.instantiate() as CanvasLayer
	inventory_screen.name = "InventoryScreen"; inventory_screen.visible = false; add_child(inventory_screen)

	shop_screen = ShopScreenScene.instantiate() as CanvasLayer
	shop_screen.name = "ShopScreen"; shop_screen.visible = false; add_child(shop_screen)

	cm.connect("combat_started", Callable(self, "_on_combat_started"))
	cm.connect("combat_started", Callable(combat_screen, "start_combat"))
	cm.connect("combat_log", Callable(combat_screen, "update_status"))
	cm.connect("combat_log", Callable(self, "_on_combat_log"))
	cm.connect("combat_update", Callable(combat_screen, "on_combat_update"))
	cm.connect("combat_ended", Callable(combat_screen, "end_combat"))
	cm.connect("combat_ended", Callable(self, "_on_combat_ended"))
	cm.connect("dice_rolled", Callable(combat_screen, "_show_dice"))

	var hud: CanvasLayer = PlayerHUD.instantiate() as CanvasLayer; hud.name = "PlayerHUD"; hud.visible = false; add_child(hud); _hud = hud

	var map_scr: GDScript = load("res://scripts/DungeonMap.gd") as GDScript
	_map_screen = map_scr.new() as CanvasLayer
	_map_screen.name = "DungeonMap"; _map_screen.visible = false; add_child(_map_screen)


	var env: Environment = $WorldEnvironment.environment
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_color = Color("432d6d")

	# Show title screen, then start game
	var title: CanvasLayer = load("res://scenes/TitleScreen.tscn").instantiate() as CanvasLayer
	title.name = "TitleScreen"
	title.play_pressed.connect(_on_title_play)
	add_child(title)


func _on_title_play() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	if _hud: _hud.visible = true
	_build_start_room()


# ============Ã‚Â
# Fade transition
# ============Ã‚Â

func _fade_transition(callback: Callable) -> void:
	if _transitioning: return
	_transitioning = true
	var t: Tween = create_tween()
	t.tween_property(_fade, "modulate:a", 1.0, 0.25)
	t.tween_callback(callback)
	t.tween_property(_fade, "modulate:a", 0.0, 0.25)
	t.tween_callback(func(): _transitioning = false)


# ============Ã‚Â
# Room registry
# ============Ã‚Â

func _register_room(template_idx: int, data: Dictionary, parent_id: String) -> Dictionary:
	var rid: String = "Room_%d" % _next_room_id
	_next_room_id += 1
	var el: Array = []
	for ex in data["exits"]:
		var ed: Dictionary = ex as Dictionary
		el.append({"dir": ed["dir"], "tile": ed["tile"], "porch": ed["porch"], "linked": ""})
	var s: Dictionary = {
		"id": rid, "template": template_idx, "tiles": data["tiles"],
		"center": data["center"], "entrance": data["entrance"],
		"exits": el, "parent": parent_id, "visited": false, "contents": {},
	}
	_rooms[rid] = s
	return s


func _link_doors(porch_tile: Vector2i, from_room: String, to_room: String, to_entrance: Vector2i) -> void:
	var fwd_key: String = from_room + ":" + str(porch_tile)
	var back_key: String = to_room + ":" + str(to_entrance)
	_door_pairs[fwd_key] = {"target": to_room, "paired": to_entrance, "parent": from_room}
	_door_pairs[back_key] = {"target": from_room, "paired": porch_tile, "parent": to_room}
	# Update exit linked field
	var rs: Dictionary = _rooms.get(from_room, {})
	for ex in rs.get("exits", []):
		var ed: Dictionary = ex as Dictionary
		if ed["porch"] == porch_tile:
			ed["linked"] = to_room
			break


# ============Ã‚Â
# Room building
# ============Ã‚Â

func _build_start_room() -> void:
	var rg: RoomGenerator = RoomGenerator.new()
	var data: Dictionary = rg.generate_single(3)
	_current_exits = data["exits"]
	_current_entrance = data["entrance"]
	var state: Dictionary = _register_room(3, data, "")
	_current_room_id = state["id"]
	_entrance_room_id = state["id"]
	state["visited"] = true
	AudioManager.play("game_start")
	_build_room_geometry(data, state)
	_spawn_player(data["entrance"] + Vector2i(0, -2), data)
	Globals.current_direction = "north"
	_spawn_merchant(data["center"] + Vector2i(1, 1))
	_give_starting_equipment()
	Globals.room_positions[state["id"]] = Vector2i.ZERO
	Globals.room_entry_dirs[state["id"]] = ""
	if _hud and _hud.has_method("set_explored"): _hud.set_explored(false)
	_notify("You stand at the dungeon entrance. A merchant eyes you.", Color.WHITE)
	print("[World] Entrance %s built (Room4)" % state["id"])

func _on_mobile() -> bool:
	return OS.get_name() == "Android" or OS.has_feature("mobile")

func _on_mobile_interact() -> void:
	# Reuse the same interact logic as keyboard E press
	var ev := InputEventAction.new()
	ev.action = "interact"
	ev.pressed = true
	Input.parse_input_event(ev)

func _on_mobile_inventory() -> void:
	if shop_screen and shop_screen.visible:
		shop_screen.close()
	if inventory_screen and not inventory_screen.visible:
		inventory_screen.open()
	elif inventory_screen:
		inventory_screen.close()

func _on_mobile_map() -> void:
	if _map_screen and _map_screen.visible:
		AudioManager.play("map_close")
		_map_screen.close()
	elif _map_screen and _map_screen.has_method("open"):
		AudioManager.play("map_open")
		_map_screen.open(_rooms, _cycle_links, _current_room_id, _entrance_room_id)


func _build_room_from_state(room_id: String, entry_tile: Vector2i) -> void:
	_clear_room()
	var state: Dictionary = _rooms.get(room_id, {})
	if state.is_empty(): return

	_current_room_id = room_id
	var data: Dictionary = _gen_room_data(state["template"])
	_current_exits = data["exits"]
	_current_entrance = data["entrance"]

	_build_room_geometry(data, state)

	# Player  one tile into the room from the door
	_spawn_player(_spawn_point_from_entry(data, entry_tile), data, entry_tile)

	# Merchant in entrance room
	if room_id == _entrance_room_id:
		_spawn_merchant(data["center"] + Vector2i(1, 1))

	# Boss room re-entry
	if room_id == _boss_room_id:
		_spawn_boss_at(data["center"])

	# Room contents
	if not state["visited"]:
		state["visited"] = true
		if not ResourceStash.boss_active:
			_notify("You enter a new area...", Color.WHITE)
			var contents: Dictionary = GameData.roll_room_contents()
			state["contents"] = contents
			_spawn_room_contents(contents, data["center"])
			if _hud and _hud.has_method("set_explored"): _hud.set_explored(true)
		else:
			_notify("A hollow silence fills this room...", Color.DIM_GRAY)
	else:
		# Respawn unsolved puzzle pedestal on revisit
		if state.get("contents", {}).get("primary", "") == "puzzle" and not state.get("puzzle_solved", false):
			_spawn_puzzle_pedestal(data["center"])
		if _hud and _hud.has_method("set_explored"): _hud.set_explored(false)
		# Wandering enemy patrol — only source of gold on revisited rooms
		if room_id != _boss_room_id and GameData.roll(4) == 1 and not ResourceStash.boss_active:
			_spawn_wandering_enemy(data["center"])
			_spawn_pickup(tile_to_world(data["center"]), GameData.roll(6) + 2, {})
func _build_new_room(template_idx: int, parent_id: String, porch_tile: Vector2i, exit_dir: String = "") -> void:
	_clear_room()
	var data: Dictionary = _gen_room_data(template_idx)
	_current_exits = data["exits"]
	_current_entrance = data["entrance"]

	var state: Dictionary = _register_room(template_idx, data, parent_id)
	_current_room_id = state["id"]
	state["visited"] = true

	_build_room_geometry(data, state)

	# Link doors between parent and new room
	_link_doors(porch_tile, parent_id, state["id"], data["entrance"])

	# Player  two tiles north of entrance, deep inside room
	#_spawn_player(data["entrance"] + Vector2i(0, -2), data)
	# Contents skip if boss is active
	var parent_entry: String = Globals.room_entry_dirs.get(parent_id, "")
	var travel_dir: String = exit_dir
	if parent_entry == "east":
		match exit_dir: 
			"north": travel_dir = "east"; 
			"east": travel_dir = "south"; 
			"south": travel_dir = "west"; 
			"west": travel_dir = "north"
	elif parent_entry == "west":
		match exit_dir: 
			"north": travel_dir = "west"; 
			"west": travel_dir = "south"; 
			"south": travel_dir = "east"; 
			"east": travel_dir = "north"
	elif parent_entry == "south":
		match exit_dir: 
			"north": travel_dir = "south"; 
			"west": travel_dir = "east"; 
			"south": travel_dir = "north"; 
			"east": travel_dir = "west"
	Globals.current_direction = travel_dir if travel_dir != "" else "north"
	
	_spawn_player(data["entrance"] + Vector2i(0, -2), data)
	# Contents ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â skip if boss is active
	if not ResourceStash.boss_active:
		var contents: Dictionary = GameData.roll_room_contents()
		state["contents"] = contents
		_spawn_room_contents(contents, data["center"])
		if _hud and _hud.has_method("set_explored"): _hud.set_explored(true)
		_notify("You enter a new area...", Color.WHITE)
	else:
		_notify("A hollow silence fills this room...", Color.DIM_GRAY)

	# Compute map position for cycle detection
	var parent_map_pos: Vector2i = Globals.room_positions.get(parent_id, Vector2i.ZERO)
	var offset: Vector2i = Vector2i.ZERO
	if travel_dir == "north": offset = Vector2i(0, -1)
	elif travel_dir == "south": offset = Vector2i(0, 1)
	elif travel_dir == "east":  offset = Vector2i(1, 0)
	elif travel_dir == "west":  offset = Vector2i(-1, 0)
	Globals.room_positions[state["id"]] = parent_map_pos + offset
	Globals.room_entry_dirs[state["id"]] = travel_dir
	print("[World] %s created (T%d) from %s  dir=%s  pos=%s" % [state["id"], template_idx + 1, parent_id, exit_dir, Globals.room_positions[state["id"]]])


## Build the final boss arena. Uses Room 1 template (3x3, no exits).
func _build_boss_room(parent_id: String, porch_tile: Vector2i) -> void:
	_clear_room()
	var data: Dictionary = _gen_room_data(0)  # 3x3 arena
	data["exits"] = []  # Boss room has no exits, final fight!
	_current_exits = data["exits"]
	_current_entrance = data["entrance"]

	var state: Dictionary = _register_room(0, data, parent_id)
	_current_room_id = state["id"]
	_boss_room_id = state["id"]
	state["visited"] = true

	_build_room_geometry(data, state)
	_link_doors(porch_tile, parent_id, state["id"], data["entrance"])
	_spawn_player(data["entrance"] + Vector2i(0, -2), data)

	# Spawn the Greater Demon
	var boss_data: Dictionary = GameData.BOSS.duplicate()
	var inst: EnemyPlaceholder = EnemyPlaceholder.instantiate()
	inst.init_from_data(boss_data)
	inst.position = tile_to_world(data["center"])
	inst.add_to_group("room_geo")
	add_child(inst)

	AudioManager.play("boss_reveal")
	_notify("THE GREATER DEMON RIIISES BEFORE YOU!", Color.RED)

	var player: Node = get_node_or_null("Player")
	if player:
		var cm: CombatManager = get_node_or_null("CombatManager") as CombatManager
		if cm and not cm.is_active():
			cm.start_combat(player as CharacterBody3D, inst)


func _gen_room_data(template_idx: int) -> Dictionary:
	var rg: RoomGenerator = RoomGenerator.new()
	return rg.generate_single(template_idx)


func _build_room_geometry(data: Dictionary, state: Dictionary) -> void:
	# Per-room stone tint — pick once and store in room state
	var tint: Color = state.get("tint", Color.WHITE)
	if tint == Color.WHITE:
		tint = _random_tint()
		state["tint"] = tint
	_current_tint = tint

	var raw: Array = data["tiles"]
	Globals.walkable_tiles = []
	for t in raw:
		Globals.walkable_tiles.append(t as Vector2i)

	for t in raw:
		var tile: Vector2i = t as Vector2i
		var cell: Cell = CellScene.instantiate()
		cell.add_to_group("room_geo")
		add_child(cell)
		cell.position = tile_to_world(tile)
		cell.update_faces(Globals.walkable_tiles)
		cell.apply_tint(tint)

	# Exit doors
	for ex in data["exits"]:
		var ed: Dictionary = ex as Dictionary
		_create_door_at(ed["porch"], ed["dir"])

	# Entrance door for non-start rooms
	if _current_room_id != _entrance_room_id:
		_create_door_at(data["entrance"], "south")

	# Random ambient light per room for visual variety
	_randomize_ambient()
	_spawn_decorations(data)

func _face_player_into_room(player: Node3D, room_data: Dictionary, entry_tile: Vector2i) -> void:
	# From entrance or first spawn - always face north into the room
	if entry_tile == room_data["entrance"] or entry_tile == Vector2i.ZERO:
		player.rotation_degrees.y = 0.0
		return
	# From exit - face into the room (opposite of exit direction)
	for ex in room_data["exits"]:
		var ed: Dictionary = ex as Dictionary
		if ed["porch"] == entry_tile:
			var dr: String = ed["dir"] as String
			match dr:
				"north": player.rotation_degrees.y = 180.0
				"south": player.rotation_degrees.y = 0.0
				"east":  player.rotation_degrees.y = 90.0
				"west":  player.rotation_degrees.y = -90.0
			return
	# Fallback: face north
	player.rotation_degrees.y = 0.0

func _spawn_player(tile: Vector2i, room_data: Dictionary = {}, entry_tile: Vector2i = Vector2i.ZERO) -> void:
	var player: CharacterBody3D = get_node_or_null("Player") as CharacterBody3D
	if not player:
		player = Player.instantiate() as CharacterBody3D
		player.name = "Player"
		add_child(player)
	player.position = tile_to_world(tile)
	if player.has_method("set_grid_position"):
		player.set_grid_position(tile)
	if not room_data.is_empty():
		_face_player_into_room(player, room_data, entry_tile)
	_room_enter_time = Time.get_ticks_msec() * 0.001
	if player is GridPlayer:
		var gp := player as GridPlayer
		gp.movement_locked_until = _room_enter_time + 0.3
		if _on_mobile():
			gp.is_mobile = true


func _spawn_merchant(tile: Vector2i) -> void:
	var merchant: CharacterBody3D = get_node_or_null("Merchant") as CharacterBody3D
	if not merchant:
		merchant = Merchant.instantiate() as CharacterBody3D
		merchant.name = "Merchant"
		add_child(merchant)
	var player: Node = get_node_or_null("Player")
	if player: merchant.player_char = player
	merchant.position = tile_to_world(tile)


func _clear_room() -> void:
	var merchant: Node = get_node_or_null("Merchant")
	if merchant and _current_room_id == _entrance_room_id:
		merchant.queue_free()

	_pedestal = null

	# Remove all room geometry (cells, doors, pedestal)
	for node in get_tree().get_nodes_in_group("room_geo"):
		if is_instance_valid(node): node.queue_free()

	# Remove entities and triggers
	var to_free: Array[Node] = []
	for child in get_children():
		if child is EnemyPlaceholder or child is TrapPlaceholder:
			to_free.append(child)
		elif child is MeshInstance3D and child.get_parent() == self:
			to_free.append(child)
		elif child is Area3D and child.get_parent() == self:
			to_free.append(child)
	for node in to_free:
		if is_instance_valid(node): node.queue_free()


## Compute the spawn tile one step inside the room from any entry direction.
func _spawn_point_from_entry(room_data: Dictionary, entry_tile: Vector2i) -> Vector2i:
	# Entrance door (always south of room) - player enters northward
	if entry_tile == room_data["entrance"]:
		return entry_tile + Vector2i(0, -1)
	# Exit porch - find the in-room tile (one step from porch toward room)
	for ex in room_data["exits"]:
		var ed: Dictionary = ex as Dictionary
		if ed["porch"] == entry_tile:
			return ed["tile"] as Vector2i
	# Fallback: one tile north
	return entry_tile + Vector2i(0, -1)

func _create_door_at(tile: Vector2i, direction: String) -> void:
	var door: Door = DoorScene.instantiate() as Door
	door.add_to_group("room_geo")
	door.position = tile_to_world(tile)
	door.apply_tint(_current_tint)
	add_child(door)
	match direction:
		"north": door.rotation_degrees.y = 180
		"south": door.rotation_degrees.y = 0
		"east":  door.rotation_degrees.y = -90
		"west":  door.rotation_degrees.y = 90


# ============Ã‚Â
# Door transitions
# ============Ã‚Â

func _on_door_used(porch_tile: Vector2i) -> void:
	# Check if already linked to a room
	var key: String = _current_room_id + ":" + str(porch_tile)
	var pair: Dictionary = _door_pairs.get(key, {})
	var target: String = pair.get("target", "")
	if target != "" and _rooms.has(target):
		var ts: Dictionary = _rooms[target]
		var entry: Vector2i = pair.get("paired", ts.get("entrance", Vector2i.ZERO))
		AudioManager.play("door_open")
		_fade_transition(func(): _build_room_from_state(target, entry))
		return

	# Boss room already placed - seal remaining doors
	if _boss_room_id != "":
		AudioManager.play("door_sealed")
		_notify("The way is sealed. Face the Greater Demon!", Color.PURPLE)
		return

	# Boss active - decrement distance, create safe rooms
	if ResourceStash.boss_active and _boss_distance > 0:
		_boss_distance -= 1
		if _boss_distance <= 0:
			AudioManager.play("door_open")
			_fade_transition(func(): _build_boss_room(_current_room_id, porch_tile))
			return
		_notify("The boss is %d rooms away..." % _boss_distance, Color.PURPLE)
		# Fall through: create empty room

	# Normal room creation - check for spatial cycle first
	var rg: RoomGenerator = RoomGenerator.new()

	# Compute where the new room would be placed
	var parent_pos: Vector2i = Globals.room_positions.get(_current_room_id, Vector2i.ZERO)
	var entry_dir: String = Globals.room_entry_dirs.get(_current_room_id, "")
	var new_pos: Vector2i = parent_pos
	for ex in _current_exits:
		var ed: Dictionary = ex as Dictionary
		if ed["porch"] == porch_tile:
			var dr: String = ed.get("dir", "")
			var gdr: String = dr
			if entry_dir == "east":
				match dr: 
					"north": gdr = "east"; 
					"east": gdr = "south"; 
					"south": gdr = "west"; 
					"west": gdr = "north"
			elif entry_dir == "west":
				match dr: 
					"north": gdr = "west"; 
					"west": gdr = "south"; 
					"south": gdr = "east"; 
					"east": gdr = "north"
			elif entry_dir == "south":
				match dr: 
					"north": gdr = "south"; 
					"west": gdr = "east"; 
					"south": gdr = "north"; 
					"east": gdr = "west"
			match gdr:
				"north": new_pos = parent_pos + Vector2i(0, -1)
				"south": new_pos = parent_pos + Vector2i(0, 1)
				"east":  new_pos = parent_pos + Vector2i(1, 0)
				"west":  new_pos = parent_pos + Vector2i(-1, 0)
			break

	# Check if an existing room already occupies this position
	for rid in Globals.room_positions.keys():
		if Globals.room_positions[rid] == new_pos and rid != _current_room_id and _rooms.has(rid):
			print("[Cycle] %s exit %s -> pos %s overlaps %s" % [_current_room_id, porch_tile, new_pos, rid])
			_cycle_links.append({"from": _current_room_id, "to": rid})
			_link_doors(porch_tile, _current_room_id, rid, _rooms[rid].get("entrance", Vector2i.ZERO))
			AudioManager.play("door_open")
			_fade_transition(func(): _build_room_from_state(rid, _rooms[rid].get("entrance", Vector2i.ZERO)))
			return
	var tidx: int = randi() % rg.ROOMS.size()
	if rg.ROOMS.size() > 1:
		while tidx == _last_template:
			tidx = randi() % rg.ROOMS.size()
	_last_template = tidx
	# Find exit direction for minimap
	var edir: String = ""
	for ex in _current_exits:
		var ed: Dictionary = ex as Dictionary
		if ed["porch"] == porch_tile:
			edir = ed["dir"]
			break
	AudioManager.play("door_open")
	_fade_transition(func(): _build_new_room(tidx, _current_room_id, porch_tile, edir))


## Teleport scroll effect ÃƒÆ’Ã†â€™Ãƒâ€ Ã¢â‚¬â„¢ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â‚¬Å¡Ã‚Â¬Ãƒâ€¦Ã‚Â¡ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã†â€™Ãƒâ€šÃ‚Â¢ÃƒÆ’Ã‚Â¢ÃƒÂ¢Ã¢â€šÂ¬Ã…Â¡Ãƒâ€šÃ‚Â¬ÃƒÆ’Ã¢â‚¬Å¡Ãƒâ€šÃ‚Â fade to entrance room.
func teleport_player_to_entrance() -> void:
	if _entrance_room_id == "" or not _rooms.has(_entrance_room_id): return
	var entry_tile: Vector2i = _rooms[_entrance_room_id].get("entrance", Vector2i.ZERO)
	_fade_transition(func(): _build_room_from_state(_entrance_room_id, entry_tile))
	_notify("The scroll crumbles as you are whisked away...", Color.MAGENTA)


func _on_entrance_used() -> void:
	var cur: Dictionary = _rooms.get(_current_room_id, {})
	var pid: String = cur.get("parent", "")
	if pid == "" or not _rooms.has(pid): return

	# Find which porch in the parent room links back to this room
	var ps: Dictionary = _rooms[pid]
	var entry_tile: Vector2i = ps.get("entrance", Vector2i.ZERO)
	for ex in ps.get("exits", []):
		var ed: Dictionary = ex as Dictionary
		if ed.get("linked", "") == _current_room_id:
			entry_tile = ed["porch"]
			break

	_fade_transition(func(): _build_room_from_state(pid, entry_tile))
	AudioManager.play("door_open")
	_notify("You step back through the doorway.", Color.WHITE)


## Flee from combat: move to another room. Prefers already-explored
## linked exits, falls back to parent, then unexplored exits.
func _flee_to_another_room() -> void:
	var cur: Dictionary = _rooms.get(_current_room_id, {})
	if cur.is_empty():
		return

	# 1. Collect all linked exits (doors to already-explored rooms)
	var linked_destinations: Array = []  # [{room_id, entry_tile}]
	for ex in cur.get("exits", []):
		var ed: Dictionary = ex as Dictionary
		var linked: String = ed.get("linked", "")
		if linked != "" and _rooms.has(linked):
			var key: String = _current_room_id + ":" + str(ed["porch"])
			var pair: Dictionary = _door_pairs.get(key, {})
			var entry: Vector2i = pair.get("paired", _rooms[linked].get("entrance", Vector2i.ZERO))
			linked_destinations.append({"room_id": linked, "entry_tile": entry})

	# 2. Pick a random linked exit if any exist
	if not linked_destinations.is_empty():
		var dest: Dictionary = linked_destinations[randi() % linked_destinations.size()]
		AudioManager.play("door_open")
		_fade_transition(func(): _build_room_from_state(dest["room_id"], dest["entry_tile"]))
		_notify("You flee through a doorway!", Color.ORANGE)
		return

	# 3. Fallback: go to parent room
	var pid: String = cur.get("parent", "")
	if pid != "" and _rooms.has(pid):
		_on_entrance_used()
		return

	# 4. Last resort: go through any unexplored exit
	for ex in _current_exits:
		var ed: Dictionary = ex as Dictionary
		var porch: Vector2i = ed["porch"]
		var key: String = _current_room_id + ":" + str(porch)
		if not _door_pairs.has(key):
			_notify("You flee into the unknown!", Color.ORANGE)
			_on_door_used(porch)
			return

	# 5. No escape possible (shouldn't normally happen)
	_notify("No escape route found!", Color.RED)


# ============Ã‚Â
# Room contents
# ===============Ã‚Â

func _spawn_room_contents(contents: Dictionary, center: Vector2i) -> void:
	var primary: String = contents.get("primary", "")
	match primary:
		"enemy", "strong_enemy":
			var d: Dictionary = contents.get("enemy", {})
			if not d.is_empty(): _spawn_enemy_at(center, d)
			_spawn_pickup(tile_to_world(center), GameData.roll(4), {})
		"patrol":
			var d1: Dictionary = contents.get("enemy", {})
			var d2: Dictionary = contents.get("enemy2", {})
			if not d1.is_empty(): _spawn_enemy_at(center + Vector2i(-1,0), d1)
			if not d2.is_empty(): _spawn_enemy_at(center + Vector2i(1,0), d2)
			_spawn_pickup(tile_to_world(center), GameData.roll(6) + 2, {})
			_notify("A patrol of enemies blocks your path!", Color.ORANGE)
		"horde":
			var h1: Dictionary = contents.get("enemy", {})
			var h2: Dictionary = contents.get("enemy2", {})
			var h3: Dictionary = contents.get("enemy3", {})
			var h4: Dictionary = contents.get("enemy4", {})
			if not h1.is_empty(): _spawn_enemy_at(center + Vector2i(-1,-1), h1)
			if not h2.is_empty(): _spawn_enemy_at(center + Vector2i(1,-1), h2)
			if not h3.is_empty(): _spawn_enemy_at(center + Vector2i(0,1), h3)
			if not h4.is_empty(): _spawn_enemy_at(center + Vector2i(1,1), h4)
			_spawn_pickup(tile_to_world(center), GameData.roll(6) + 4, {})
			_notify("A HORDE of enemies swarms toward you!", Color.RED)
		"trap":
			var d: Dictionary = contents.get("trap", {})
			if not d.is_empty(): _spawn_trap_at(center, d)
		"healing_spring": _spawn_spring_at(center)
		"puzzle": _spawn_puzzle_pedestal(center)
		"store_room":
			var t: Dictionary = contents.get("treasure", {})
			if not t.is_empty(): _spawn_pickup(tile_to_world(center), 0, t)
		"messy":
			var sub: String = contents.get("sub_type", "")
			match sub:
				"enemy": _spawn_enemy_at(center, contents.get("enemy", {}))
				"trap": _spawn_trap_at(center, contents.get("trap", {}))
				"treasure": _spawn_pickup(tile_to_world(center), 0, contents.get("treasure", {}))
				"gold": _spawn_pickup(tile_to_world(center), contents.get("gold_amount", GameData.roll(6)), {})
				_: 
					_notify("A dusty room with scattered debris.", Color.DIM_GRAY)
					_spawn_pickup(tile_to_world(center), GameData.roll(6), {})


func _spawn_enemy_at(center: Vector2i, data: Dictionary) -> void:
	if _debug_no_spawn: return
	var inst: EnemyPlaceholder = EnemyPlaceholder.instantiate(); inst.init_from_data(data)
	inst.position = tile_to_world(center); inst.add_to_group("room_geo"); add_child(inst)
	_notify("%s appears!" % data.get("name", "?"), Color.ORANGE)
	var player2: Node = get_node_or_null("Player")
	if player2:
		var cm2: CombatManager = get_node_or_null("CombatManager") as CombatManager
		if cm2 and not cm2.is_active():
			cm2.start_combat(player2 as CharacterBody3D, inst)

func _spawn_trap_at(center: Vector2i, data: Dictionary) -> void:
	var inst: TrapPlaceholder = TrapPlaceholder.instantiate(); inst.init_from_data(data)
	inst.position = tile_to_world(center) + Vector3(randf_range(-0.8,0.8), 0, randf_range(-0.8,0.8))
	inst.rotation_degrees.y = randi() % 360; inst.add_to_group("room_geo"); add_child(inst)
	var area: Area3D = Area3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new(); shape.radius = 1.0; shape.height = 1.5
	var cs: CollisionShape3D = CollisionShape3D.new(); cs.shape = shape; area.add_child(cs)
	area.position = inst.position
	area.connect("body_entered", Callable(self, "_on_trap_trigger").bind(inst, area)); add_child(area)
	_notify("You spot a %s on the floor..." % data.get("name", "?"), Color.ORANGE)

func _spawn_spring_at(center: Vector2i) -> void:
	# Skip if already used in this room
	var state: Dictionary = _rooms.get(_current_room_id, {})
	if state.get("spring_used", false): return

	var pos: Vector3 = tile_to_world(center)
	var mi: MeshInstance3D = MeshInstance3D.new()
	var cyl: CylinderMesh = CylinderMesh.new(); cyl.top_radius = 0.5; cyl.bottom_radius = 0.5; cyl.height = 0.15
	mi.mesh = cyl
	var mat: StandardMaterial3D = StandardMaterial3D.new()
	mat.albedo_color = Color(0.2, 0.7, 1.0, 0.7)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mi.material_override = mat
	mi.position = pos; mi.add_to_group("room_geo"); add_child(mi)
	var area: Area3D = Area3D.new()
	var shape: CylinderShape3D = CylinderShape3D.new(); shape.radius = 1.0; shape.height = 1.5
	var cs: CollisionShape3D = CollisionShape3D.new(); cs.shape = shape; area.add_child(cs)
	area.position = pos; area.add_to_group("room_geo")
	area.connect("body_entered", Callable(self, "_on_spring_trigger").bind(mi, area)); add_child(area)
	_notify("A glowing pool shimmers...", Color.CYAN)


func _spawn_puzzle_pedestal(center: Vector2i) -> void:
	var state: Dictionary = _rooms.get(_current_room_id, {})
	if state.get("puzzle_solved", false):
		return

	var ped: PuzzlePedestal = PuzzlePedestalScene.instantiate()
	ped.position = tile_to_world(center)
	ped.add_to_group("room_geo")
	ped.player_activated.connect(_on_puzzle_activated)
	add_child(ped)
	_pedestal = ped
	_notify("An ancient pedestal pulses with light...", Color.GOLD)


func _on_puzzle_activated() -> void:
	if _pedestal == null or _pedestal.solved:
		return

	var state: Dictionary = _rooms.get(_current_room_id, {})
	var puzzle_type: String = state.get("puzzle_type", "")
	if puzzle_type == "":
		var types: Array[String] = ["riddle", "symbol_match", "rune_memory"]
		puzzle_type = types[randi() % types.size()]
		state["puzzle_type"] = puzzle_type

	match puzzle_type:
		"rune_memory":
			var screen: RuneMemoryScreen = RuneMemoryScreenScene.instantiate()
			get_tree().root.add_child(screen)
			screen.puzzle_result.connect(_on_puzzle_result)
			screen.open()

		"symbol_match":
			var puzzle: Dictionary = GameData.roll_symbol_puzzle()
			var scr := PuzzleScreenScene.instantiate()
			get_tree().root.add_child(scr)
			scr.puzzle_result.connect(_on_puzzle_result)
			scr.open(puzzle)

		_:
			var riddle: Dictionary = state.get("contents", {}).get("riddle", {})
			if riddle.is_empty():
				riddle = GameData.roll_riddle()
			var scr2 := PuzzleScreenScene.instantiate()
			get_tree().root.add_child(scr2)
			scr2.puzzle_result.connect(_on_puzzle_result)
			scr2.open(riddle)


func _on_puzzle_result(correct: bool) -> void:
	var state: Dictionary = _rooms.get(_current_room_id, {})
	var player := get_node_or_null("Player") as GridPlayer

	if correct:
		state["puzzle_solved"] = true
		if _pedestal:
			_pedestal.mark_solved()
		# Reward
		var reward: int = 4 + GameData.roll(6)
		ResourceStash.add_gold(reward)
		var treasure: Dictionary = GameData.TREASURES[GameData.roll(12)].duplicate()
		ResourceStash.add_item(treasure)
		_notify("Puzzle solved! +%d gold and a %s!" % [reward, treasure.get("name", "treasure")], Color.GOLD)
	else:
		# Punishment: altar breaks, d4 damage, enemy spawns
		state["puzzle_solved"] = true
		var spawn_pos: Vector2i = Vector2i.ZERO
		if _pedestal:
			spawn_pos = Vector2i(int(_pedestal.position.x / Globals.GRID_SIZE),
				int(_pedestal.position.z / Globals.GRID_SIZE))
			_pedestal.queue_free()
			_pedestal = null

		AudioManager.play("trap_trigger")
		_notify("The altar shatters!", Color.RED)

		var dmg: int = GameData.roll(4)
		if player:
			player.health = max(0, player.health - dmg)
			_notify("You take %d damage!" % dmg, Color.RED)
			if _hud and _hud.has_method("flash_red"):
				_hud.flash_red()
			if player.health <= 0:
				_game_over()
				return
		# Spawn enemy at room center (guaranteed walkable), combat repositions
		var enemy_data: Dictionary = GameData.roll_enemy()
		if not enemy_data.is_empty():
			var room_center: Vector2i = _rooms.get(_current_room_id, {}).get("center", spawn_pos)
			_spawn_enemy_at(room_center, enemy_data)


func _spawn_wandering_enemy(center: Vector2i) -> void:
	var data: Dictionary = GameData.roll_enemy()
	if data.is_empty(): return
	_spawn_enemy_at(center, data)
	_notify("A wandering %s appears!" % data.get("name", "enemy"), Color.ORANGE)


## Spawn the Greater Demon boss. Called on first entry and re-entry.
func _spawn_boss_at(center: Vector2i) -> void:
	if _debug_no_spawn: return
	var boss_data: Dictionary = GameData.BOSS.duplicate()
	var inst: EnemyPlaceholder = EnemyPlaceholder.instantiate()
	inst.init_from_data(boss_data)
	inst.position = tile_to_world(center)
	inst.add_to_group("room_geo")
	add_child(inst)
	_notify("THE GREATER DEMON RIIISES BEFORE YOU!", Color.RED)
	var player2: Node = get_node_or_null("Player")
	if player2:
		var cm2: CombatManager = get_node_or_null("CombatManager") as CombatManager
		if cm2 and not cm2.is_active():
			cm2.start_combat(player2 as CharacterBody3D, inst)


# =========Ã‚Â
# Combat
# =========Ã‚Â

func _on_combat_started(_p: CharacterBody3D, _enemy: CharacterBody3D) -> void:
	pass  # Camera positioning handled by CombatScreen.start_combat

func _on_combat_log(msg: String) -> void:
	if "You hit" in msg or ("hits for" in msg and "Enemy" not in msg): combat_screen.flash_white()
	elif "Enemy hits" in msg: combat_screen.flash_red()

func _on_combat_ended(_p: CharacterBody3D, enemy: CharacterBody3D, victory: bool) -> void:
	var p: Node = get_node_or_null("Player")
	if p and p is GridPlayer: (p as GridPlayer).unlock_camera()
	if not victory:
		var pp: GridPlayer = get_node_or_null("Player") as GridPlayer
		if pp and pp.health <= 0:
			_game_over()
			return
		# Hide combat screen immediately so it doesn't linger during fade
		if combat_screen:
			combat_screen.visible = false
		_notify("Routed! You retreat.", Color.RED)
		_flee_to_another_room()
		return
	if "treasure_drop_min" in enemy:
		var tmin: int = enemy.treasure_drop_min
		if tmin > 0 and randi() % 6 + 1 >= tmin: _spawn_pickup(enemy.position, 0, GameData.roll_treasure())
	if randi() % 3 == 0: _spawn_pickup(enemy.position, randi() % 6 + 2, {})
	ResourceStash.kill_count += 1

	# Boss defeated Ã¢â‚¬â€ show victory screen
	if "enemy_name" in enemy and enemy.enemy_name == "Greater Demon":
		ResourceStash.boss_defeated = true
		enemy.queue_free()
		_victory()
		return
	if ResourceStash.kill_count >= _total_max_kills and not ResourceStash.boss_active:
		ResourceStash.boss_active = true
		_boss_distance = GameData.roll(4)
		AudioManager.play("boss_awaken")
		_notify("The dungeon trembles... The Greater Demon awaits %d rooms away!" % _boss_distance, Color.PURPLE)

	enemy.queue_free()

func _on_enemy_trigger(body: Node3D, enemy: EnemyPlaceholder, area: Area3D) -> void:
	if not body is GridPlayer: return
	var elapsed: float = Time.get_ticks_msec() * 0.001 - _room_enter_time
	if elapsed < 1.5: return
	area.monitoring = false
	var cm: CombatManager = get_node_or_null("CombatManager") as CombatManager
	if cm and not cm.is_active(): cm.start_combat(body as CharacterBody3D, enemy)

func _on_trap_trigger(body: Node3D, trap: Node, area: Node) -> void:
	if not body is GridPlayer: return
	# Grace period after entering room — don't trigger traps immediately at door
	var elapsed: float = Time.get_ticks_msec() * 0.001 - _room_enter_time
	if elapsed < 0.3: return
	area.monitoring = false
	var t: TrapPlaceholder = trap as TrapPlaceholder
	if t == null: return

	# Store pending trap info and show dice overlay for player roll
	_pending_trap = {"trap": t, "player": body, "area": area}

	var overlay := DiceOverlayScene.instantiate()
	get_tree().root.add_child(overlay)
	overlay.roll_result.connect(_on_trap_dice_result)
	overlay.open(8, "Evade Trap: 8")


func _on_trap_dice_result(roll_val: int) -> void:
	var trap: TrapPlaceholder = _pending_trap.get("trap") as TrapPlaceholder
	var player: GridPlayer = _pending_trap.get("player") as GridPlayer
	var area: Node = _pending_trap.get("area")
	_pending_trap = {}

	if trap == null or player == null:
		return

	var result: Dictionary = trap.resolve(roll_val)
	_notify(result.get("message", "A trap!"), Color.ORANGE if result.get("evaded", false) else Color.RED)
	if result.get("evaded", false):
		trap.queue_free()
		return

	AudioManager.play("trap_trigger")

	# Teleport trap — walk parent chain N rooms back
	var teleport_rooms: int = result.get("teleport_rooms", 0)
	if teleport_rooms > 0:
		var target_id: String = _current_room_id
		for _i in range(teleport_rooms):
			var cur: Dictionary = _rooms.get(target_id, {})
			var pid: String = cur.get("parent", "")
			if pid == "" or not _rooms.has(pid): break
			target_id = pid
		if target_id != _current_room_id:
			var target_state: Dictionary = _rooms[target_id]
			_notify("Teleported %d rooms back!" % teleport_rooms, Color.MAGENTA)
			trap.queue_free()
			_fade_transition(func(): _build_room_from_state(target_id, target_state.get("entrance", Vector2i.ZERO)))
			return

	var dmg: int = result.get("damage", 0)
	var red: int = max(0, dmg - ResourceStash.trap_damage_reduction)
	if red < dmg: _notify("Armour reduces damage by %d!" % (dmg - red), Color.CYAN)
	if red > 0:
		AudioManager.play("player_damage")
		player.health = max(0, player.health - red)
		_notify("You take %d damage! HP: %d" % [red, player.health], Color.RED)
	if red > 0 and _hud and _hud.has_method("flash_red"): _hud.flash_red()
	if player.health <= 0:
		_game_over()
		return
	trap.queue_free()

func _on_spring_trigger(body: Node3D, mesh: MeshInstance3D, area: Area3D) -> void:
	if not body is GridPlayer: return
	# Grace period after entering room
	var elapsed: float = Time.get_ticks_msec() * 0.001 - _room_enter_time
	if elapsed < 0.3: return
	area.monitoring = false

	# Store pending and show dice overlay for player roll
	_pending_spring = {"mesh": mesh, "area": area, "player": body}

	var overlay := DiceOverlayScene.instantiate()
	get_tree().root.add_child(overlay)
	overlay.roll_result.connect(_on_spring_dice_result)
	overlay.open(6, "Heal on Roll")


func _on_spring_dice_result(roll_val: int) -> void:
	var mesh: MeshInstance3D = _pending_spring.get("mesh")
	var area: Area3D = _pending_spring.get("area")
	var player: GridPlayer = _pending_spring.get("player")
	_pending_spring = {}

	if mesh and is_instance_valid(mesh): mesh.queue_free()
	if area and is_instance_valid(area): area.queue_free()

	if player:
		player.health = min(player.max_health, player.health + roll_val)
		AudioManager.play("healing_spring")
		_notify("The spring restores %d HP! (HP: %d)" % [roll_val, player.health], Color.GREEN)

	if _rooms.has(_current_room_id):
		_rooms[_current_room_id]["spring_used"] = true

func _spawn_pickup(pos: Vector3, gold: int, item: Dictionary = {}) -> void:
	var scr: GDScript = load("res://scripts/Pickup.gd") as GDScript
	if item.is_empty() and gold > 0:
		var p: Area3D = scr.new() as Area3D; p.init_gold(gold)
		p.position = pos + Vector3(randf_range(-0.5,0.5), 0, randf_range(-0.5,0.5)); add_child(p)
	elif not item.is_empty():
		var p: Area3D = scr.new() as Area3D; p.init_item(item)
		p.position = pos + Vector3(randf_range(-0.5,0.5), 0, randf_range(-0.5,0.5)); add_child(p)
		_notify("Found %s!" % item.get("name","treasure"), Color.GOLD)


# ========Ã‚Â
# Input
# ========Ã‚Â

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_F1 and event.pressed:
		_debug_no_spawn = not _debug_no_spawn
		if _hud and _hud.has_method("show_notification"):
			_hud.show_notification("Enemy spawns: " + ("OFF" if _debug_no_spawn else "ON"), Color.YELLOW if _debug_no_spawn else Color.GREEN, 1.5)
		return

	if event is InputEventKey and event.keycode == KEY_M and event.pressed:
		if combat_screen and combat_screen.visible: return
		if _map_screen and _map_screen.visible:
			AudioManager.play("map_close")
			_map_screen.close()
		elif _map_screen and _map_screen.has_method("open"):
			AudioManager.play("map_open")
			_map_screen.open(_rooms, _cycle_links, _current_room_id, _entrance_room_id)
		return

	if event.is_action_pressed("inventory"):
		if shop_screen and shop_screen.visible: shop_screen.close()
		if inventory_screen and not inventory_screen.visible:
			inventory_screen.open()
		elif inventory_screen: inventory_screen.close()

	if event.is_action_pressed("interact"):
		if _transitioning: return
		if combat_screen.visible: return
		if inventory_screen and inventory_screen.visible: return
		if shop_screen and shop_screen.visible: shop_screen.close(); return
		if Time.get_ticks_msec() * 0.001 - _room_enter_time < 0.8: return

		var p: Node = get_node_or_null("Player")
		if not p: return

		if p is GridPlayer:
			var pp: GridPlayer = p as GridPlayer
			var pos: Vector3 = pp.global_position
			var forward: Vector3 = -pp.basis.z

			for ex in _current_exits:
				var ed: Dictionary = ex as Dictionary
				var porch_world: Vector3 = tile_to_world(ed["porch"])
				var to_door: Vector3 = (porch_world - pos).normalized()
				if pos.distance_to(porch_world) < 2.2 and forward.dot(to_door) > 0.5:
					_on_door_used(ed["porch"])
					return

			if _current_room_id != _entrance_room_id:
				var ent_world: Vector3 = tile_to_world(_current_entrance)
				var to_ent: Vector3 = (ent_world - pos).normalized()
				if pos.distance_to(ent_world) < 2.2 and forward.dot(to_ent) > 0.5:
					_on_entrance_used()
					return

		# Puzzle pedestal interaction
		if _pedestal and is_instance_valid(_pedestal) and not _pedestal.solved:
			if _pedestal.check_interact(p.global_position):
				return

		var merchant: Node = get_node_or_null("Merchant")
		if merchant and p.global_position.distance_to(merchant.global_position) < 2.0:
			shop_screen.open(); return

# =======
# Helpers
# =======Ã‚Â

func tile_to_world(tile: Vector2i, y_offset: float = 0.0) -> Vector3:
	return Vector3(tile.x * Globals.GRID_SIZE, y_offset, tile.y * Globals.GRID_SIZE)


## Per rulebook: roll d4 on weapons + treasure tables for starting gear.
func _give_starting_equipment() -> void:
	if ResourceStash.inventory.size() > 0:
		return  # Already equipped
	var wpn: Dictionary = GameData.WEAPONS[GameData.roll(4)].duplicate()
	wpn["slot"] = "weapon"
	ResourceStash.add_item(wpn)
	var idx: int = ResourceStash.inventory.size() - 1
	if idx >= 0:
		ResourceStash.equip(idx)
	var trs: Dictionary = GameData.TREASURES[GameData.roll(4)].duplicate()
	ResourceStash.add_item(trs)
	_notify("You carry a %s and a %s." % [wpn["name"], trs["name"]], Color.CYAN)


## Vary ambient light color per room for dungeon atmosphere.
func _randomize_ambient() -> void:
	var env: Environment = $WorldEnvironment.environment
	var r: float = randf()
	if r < 0.25:
		env.ambient_light_color = Color("463663ff")
	elif r < 0.5:
		env.ambient_light_color = Color("375237ff")
	elif r < 0.75:
		env.ambient_light_color = Color("4b2e2eff")
	else:
		env.ambient_light_color = Color("1a1a2d")


## Pick a subtle stone tint per room so walls and doors feel distinct.
func _random_tint() -> Color:
	var tints: Array[Color] = [
		Color(0.90, 0.82, 0.72),   # warm sandstone
		Color(0.72, 0.78, 0.92),   # cool blue stone
		Color(0.78, 0.88, 0.75),   # mossy green stone
		Color(0.85, 0.76, 0.84),   # arcane purple stone
		Color(0.80, 0.75, 0.68),   # deep brown stone
		Color(0.80, 0.82, 0.88),   # slate blue-gray
	]
	return tints[randi() % tints.size()]


## Game over player died. Shows overlay with stats and restart option.
func _game_over() -> void:
	AudioManager.play("game_over")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

	var layer := CanvasLayer.new()
	layer.name = "GameOverLayer"
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.size = get_viewport().get_visible_rect().size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)

	var vs := get_viewport().get_visible_rect().size
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(vs.x * 0.3, vs.y * 0.25)
	vbox.size = Vector2(vs.x * 0.4, vs.y * 0.5)
	overlay.add_child(vbox)

	var title := Label.new()
	title.text = "GAME OVER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color.RED)
	vbox.add_child(title)

	var stats := Label.new()
	stats.text = "Kills: %d\nGold: %d GP\nRooms explored: %d" % [ResourceStash.kill_count, ResourceStash.gold, _next_room_id]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 22)
	stats.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(stats)

	vbox.add_child(_make_spacer(20))

	var restart_btn := Button.new()
	restart_btn.text = "Try Again"
	restart_btn.custom_minimum_size = Vector2(200, 50)
	restart_btn.add_theme_font_size_override("font_size", 24)
	restart_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	restart_btn.connect("pressed", Callable(self, "_restart_game"))
	vbox.add_child(restart_btn)


func _make_spacer(h: float) -> Control:
	var c := Control.new(); c.custom_minimum_size = Vector2(0, h); return c


	
## Victory Ã¢â‚¬â€ Greater Demon defeated. Shows overlay with stats and return to menu.
func _victory() -> void:
	AudioManager.play("victory")
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	get_tree().paused = true

	var layer := CanvasLayer.new()
	layer.name = "VictoryLayer"
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(layer)

	var overlay := ColorRect.new()
	overlay.color = Color(0.05, 0.02, 0.08, 0.92)
	overlay.size = get_viewport().get_visible_rect().size
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	layer.add_child(overlay)

	var vs := get_viewport().get_visible_rect().size
	var vbox := VBoxContainer.new()
	vbox.position = Vector2(vs.x * 0.25, vs.y * 0.2)
	vbox.size = Vector2(vs.x * 0.5, vs.y * 0.6)
	overlay.add_child(vbox)

	var title := Label.new()
	title.text = "VICTORY"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color.GOLD)
	vbox.add_child(title)

	vbox.add_child(_make_spacer(8))

	var subtitle := Label.new()
	subtitle.text = "The Greater Demon lies vanquished."
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.9, 0.7, 0.3))
	vbox.add_child(subtitle)

	vbox.add_child(_make_spacer(16))

	var flavor := Label.new()
	flavor.text = "But darkness ever lurks\nwhere light dares tread.\nAnother dungeon awaits..."
	flavor.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flavor.add_theme_font_size_override("font_size", 18)
	flavor.add_theme_color_override("font_color", Color(0.6, 0.5, 0.7))
	vbox.add_child(flavor)

	vbox.add_child(_make_spacer(8))

	var stats := Label.new()
	stats.text = "Kills: %d\nGold: %d GP\nRooms explored: %d" % [ResourceStash.kill_count, ResourceStash.gold, _next_room_id]
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override("font_size", 20)
	stats.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(stats)

	vbox.add_child(_make_spacer(24))

	var menu_btn := Button.new()
	menu_btn.text = "Return to Title"
	menu_btn.custom_minimum_size = Vector2(220, 50)
	menu_btn.add_theme_font_size_override("font_size", 22)
	menu_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	menu_btn.pressed.connect(_return_to_title)
	vbox.add_child(menu_btn)

func _return_to_title() -> void:
	get_tree().paused = false
	# Remove victory layer
	var vl := get_node_or_null("VictoryLayer")
	if vl: vl.queue_free()
	# Remove game over layer if present
	var go := get_node_or_null("GameOverLayer")
	if go: go.queue_free()
	# Clean up room
	_clear_room()
	# Reset state
	_rooms.clear(); _door_pairs.clear()
	_next_room_id = 0; _current_room_id = ""; _entrance_room_id = ""
	_current_exits.clear(); _boss_room_id = ""; _boss_distance = -1
	_last_template = -1; _cycle_links.clear()
	Globals.room_positions.clear(); Globals.room_entry_dirs.clear()
	ResourceStash.gold = 0; ResourceStash.inventory.clear()
	ResourceStash.boss_defeated = false
	ResourceStash.kill_count = 0; ResourceStash.boss_active = false
	for k in ResourceStash.equipped.keys(): ResourceStash.equipped[k] = null
	ResourceStash._recalc_stats()
	# Remove player and merchant
	var player := get_node_or_null("Player")
	if player: player.queue_free()
	var merchant := get_node_or_null("Merchant")
	if merchant: merchant.queue_free()
	# Show title screen
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	var title: CanvasLayer = load("res://scenes/TitleScreen.tscn").instantiate() as CanvasLayer
	title.name = "TitleScreen"
	title.play_pressed.connect(_on_title_play)
	add_child(title)

func _restart_game() -> void:
	get_tree().paused = false
	var ov := get_node_or_null("GameOverLayer")
	if ov: ov.queue_free()

	_fade_transition(_do_restart)


func _do_restart() -> void:
	# Free merchant and player before clearing room IDs
	var merchant := get_node_or_null("Merchant")
	if merchant:
		remove_child(merchant)
		merchant.queue_free()
	var player := get_node_or_null("Player")
	if player:
		remove_child(player)
		player.queue_free()

	# Reset room state
	_rooms.clear()
	_door_pairs.clear()
	_next_room_id = 0
	_current_room_id = ""
	_entrance_room_id = ""
	_current_exits.clear()
	_boss_room_id = ""
	_boss_distance = -1
	_last_template = -1
	_cycle_links.clear()
	Globals.room_positions.clear()
	Globals.room_entry_dirs.clear()
	ResourceStash.gold = 0
	ResourceStash.inventory.clear()
	ResourceStash.kill_count = 0
	ResourceStash.boss_defeated = false
	ResourceStash.boss_active = false
	for k in ResourceStash.equipped.keys():
		ResourceStash.equipped[k] = null
	ResourceStash._recalc_stats()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_clear_room()
	_build_start_room()


## Spawn random dungeon props (torch lights, rubble) for atmosphere.
func _spawn_decorations(room_data: Dictionary) -> void:
	var tiles: Array = room_data.get("tiles", [])
	if tiles.size() < 5: return
	# Pick 2-5 random floor tiles to decorate (skip center and door tiles)
	var decor_spots: Array = []
	for t in tiles:
		var tv: Vector2i = t as Vector2i
		if tv == room_data.get("center", Vector2i.ZERO): continue
		if tv == room_data.get("entrance", Vector2i.ZERO): continue
		decor_spots.append(tv)
	if decor_spots.size() < 2: return
	decor_spots.shuffle()
	var count: int = mini(2 + randi() % 4, decor_spots.size())
	#for i in range(count):
		#var spot: Vector2i = decor_spots[i]
		#var pos: Vector3 = tile_to_world(spot) + Vector3(randf_range(-0.6,0.6), 0, randf_range(-0.6,0.6))
		#var r: int = randi() % 4 + 1  # Skip 0 (torch lights removed)
		#if r == 0:
			## Torch lightÃ‚Â small orange point light
			#var mi := MeshInstance3D.new()
			#var cyl := CylinderMesh.new()
			#cyl.top_radius = 0.3; cyl.bottom_radius = 0.4; cyl.height = 0.2
			#mi.mesh = cyl
			#var mat := StandardMaterial3D.new()
			#mat.albedo_color = Color(0.922, 0.173, 0.051, 1.0)
			#mat.roughness = 1.0
			#mi.material_override = mat
			#mi.position = pos
			#mi.rotation_degrees = Vector3(randi() % 360, randi() % 360, 0)
			#mi.add_to_group("room_geo")
			#add_child(mi)
		#elif r == 1:
			## Rubble pile,Ã‚Â small dark cylinder
			#var mi := MeshInstance3D.new()
			#var cyl := CylinderMesh.new()
			#cyl.top_radius = 0.3; cyl.bottom_radius = 0.4; cyl.height = 0.2
			#mi.mesh = cyl
			#var mat := StandardMaterial3D.new()
			#mat.albedo_color = Color(0.25, 0.22, 0.2)
			#mat.roughness = 1.0
			#mi.material_override = mat
			#mi.position = pos
			#mi.rotation_degrees = Vector3(randi() % 360, randi() % 360, 0)
			#mi.add_to_group("room_geo")
			#add_child(mi)
			#
		#elif r == 2:
			## Broken crateÃ¢â‚¬Å¡Ãƒâ€šÃ‚Â small box
			#var mi := MeshInstance3D.new()
			#var bx := BoxMesh.new()
			#bx.size = Vector3(0.4, 0.3, 0.4)
			#mi.mesh = bx
			#var mat := StandardMaterial3D.new()
			#mat.albedo_color = Color(0.4, 0.25, 0.1)
			#mat.roughness = 1.0
			#mi.material_override = mat
			#mi.position = pos
			#mi.rotation_degrees.y = randi() % 360
			#mi.add_to_group("room_geo")
			#add_child(mi)
		#else:
			## Skull/candle Ã‚Â , small sphere
			#var mi := MeshInstance3D.new()
			#var sph := SphereMesh.new()
			#sph.radius = 0.15; sph.height = 0.25
			#mi.mesh = sph
			#var mat := StandardMaterial3D.new()
			#mat.albedo_color = Color(0.551, 0.531, 0.449, 1.0)
			#mat.roughness = 0.8
			#mi.material_override = mat
			#mi.position = pos + Vector3(0, 0.15, 0)
			#mi.add_to_group("room_geo")
			#add_child(mi)

func _notify(text: String, color: Color = Color.WHITE) -> void:
	print("[Room] " + text)
	if _hud and _hud.has_method("show_notification"): _hud.show_notification(text, color)
