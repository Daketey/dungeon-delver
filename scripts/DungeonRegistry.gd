extends Node
## Dungeon state registry — source of truth for room persistence, door linking, and player reference.
## Autoload: survives room clears and transitions.

# ── Player reference (set by World.gd after spawn) ──
var player_node: GridPlayer = null

# ── Current room tracking ──
var current_room_id: String = ""
var entrance_room_id: String = ""

# ── Room state storage ──
var _room_states: Dictionary = {}    # String room_id → Dictionary state
var _next_room_index: int = 0

# ── Door pair registry ──
var _door_pairs: Dictionary = {}     # Vector2i tile → {paired: Vector2i, target_room: String}

# ── Room graph adjacency ──
var _room_graph: Dictionary = {}     # String room_id → Array[String] neighbor_ids

# ── Public API ──

func reset() -> void:
	_room_states.clear()
	_room_graph.clear()
	_door_pairs.clear()
	_next_room_index = 0
	current_room_id = ""
	entrance_room_id = ""
	player_node = null


func register_room(template_idx: int, tiles: Array, center: Vector2i,
                   entrance_tile: Vector2i, exit_defs: Array,
                   parent_id: String = "") -> Dictionary:
	var room_id: String = "Room_%d" % _next_room_index
	_next_room_index += 1

	# Build exit list from template definition
	var exit_list: Array[Dictionary] = []
	for ex: Dictionary in exit_defs:
		exit_list.append({
			"dir": ex.get("dir", ""),
			"tile": ex.get("tile", Vector2i.ZERO),
			"porch": ex.get("porch", Vector2i.ZERO),
			"target_room_id": "",
			"linked": false,
		})

	var state: Dictionary = {
		"room_id": room_id,
		"template_idx": template_idx,
		"tiles": tiles.duplicate(),
		"center": center,
		"entrance_tile": entrance_tile,
		"exits": exit_list,
		"parent_room_id": parent_id,
		"visited": false,
		"visit_count": 0,
		"contents": {},
		"entity_states": {},
		"wandering_enemy_spawned": false,
		"merchant_present": false,
	}

	_room_states[room_id] = state

	# Update room graph
	if parent_id != "" and _room_states.has(parent_id):
		if not _room_graph.has(parent_id):
			_room_graph[parent_id] = []
		if not _room_graph.has(room_id):
			_room_graph[room_id] = []
		if room_id not in _room_graph[parent_id]:
			_room_graph[parent_id].append(room_id)
		if parent_id not in _room_graph[room_id]:
			_room_graph[room_id].append(parent_id)

	return state


func link_exit_to_room(porch_tile: Vector2i, to_room_id: String, to_entrance_tile: Vector2i) -> void:
	# Find and update the exit in the current room
	var cur_state: Dictionary = get_room_state(current_room_id)
	for ex: Dictionary in cur_state.get("exits", []):
		if ex.get("porch") == porch_tile and not ex.get("linked", false):
			ex["target_room_id"] = to_room_id
			ex["linked"] = true
			break

	# Bidirectional door pair
	_door_pairs[porch_tile] = {"paired": to_entrance_tile, "target_room": to_room_id}
	_door_pairs[to_entrance_tile] = {"paired": porch_tile, "target_room": current_room_id}


func get_room_state(room_id: String) -> Dictionary:
	return _room_states.get(room_id, {})


func get_current_state() -> Dictionary:
	return _room_states.get(current_room_id, {})


func set_current_room(room_id: String) -> void:
	current_room_id = room_id


func has_room(room_id: String) -> bool:
	return _room_states.has(room_id)


func mark_visited(room_id: String) -> void:
	if _room_states.has(room_id):
		_room_states[room_id]["visited"] = true
		_room_states[room_id]["visit_count"] += 1


func is_room_visited(room_id: String) -> bool:
	return _room_states.get(room_id, {}).get("visited", false)


func set_room_contents(room_id: String, contents: Dictionary) -> void:
	if _room_states.has(room_id):
		_room_states[room_id]["contents"] = contents


func set_entity_state(room_id: String, entity_key: String, state_update: Dictionary) -> void:
	if not _room_states.has(room_id):
		return
	var estates: Dictionary = _room_states[room_id].get("entity_states", {})
	if not estates.has(entity_key):
		estates[entity_key] = {}
	for k: String in state_update:
		estates[entity_key][k] = state_update[k]
	_room_states[room_id]["entity_states"] = estates


func get_entity_states(room_id: String) -> Dictionary:
	return _room_states.get(room_id, {}).get("entity_states", {})


func get_door_entry(tile: Vector2i) -> Dictionary:
	return _door_pairs.get(tile, {})


func get_parent_room(room_id: String) -> String:
	return _room_states.get(room_id, {}).get("parent_room_id", "")


func get_neighbors(room_id: String) -> Array:
	return _room_graph.get(room_id, [])


func set_merchant_present(room_id: String, present: bool) -> void:
	if _room_states.has(room_id):
		_room_states[room_id]["merchant_present"] = present
