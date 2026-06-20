extends Node

const GRID_SIZE = 2

# Populated by World.gd after dungeon generation
var walkable_tiles: Array[Vector2i] = []

# Dungeon map state — shared across World.gd and DungeonMap.gd
var current_direction: String = "north"
var current_room_id: String = ""
var room_positions: Dictionary = {}
var room_entry_dirs: Dictionary = {}

func is_walkable(tile: Vector2i) -> bool:
	return tile in walkable_tiles
