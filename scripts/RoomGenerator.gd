extends Node2D
class_name RoomGenerator
## 10 distinct room templates for dungeon variety.

const DIR: Dictionary = {
	"north": Vector2i(0, -1),
	"south": Vector2i(0, 1),
	"east":  Vector2i(1, 0),
	"west":  Vector2i(-1, 0),
}

# 0=Crossroads 1=Fork 2=Straight 3=Start 4=Pillar 5=Arena
# 6=DeadEnd 7=Treasury 8=Cross 9=Gauntlet
# Each template maps to a pre-built room scene in res://rooms/
const ROOM_SCENES = [
	"res://rooms/Room_0_Crossroads.tscn",
	"res://rooms/Room_1_Fork.tscn",
	"res://rooms/Room_2_Straight.tscn",
	"res://rooms/Room_3_Start.tscn",
	"res://rooms/Room_4_Pillar.tscn",
	"res://rooms/Room_5_Arena.tscn",
	"res://rooms/Room_6_DeadEnd.tscn",
	"res://rooms/Room_7_Treasury.tscn",
	"res://rooms/Room_8_Cross.tscn",
	"res://rooms/Room_9_Gauntlet.tscn",
]

const ROOMS: Array[Dictionary] = [
	# 0: Crossroads — 3x3, exits N+E+W (3 choices)
	{floor=[
		Vector2i(1,1),Vector2i(2,1),Vector2i(3,1),
		Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),
		Vector2i(1,3),Vector2i(2,3),Vector2i(3,3),
	], corridor=[Vector2i(2,4)], entrance=Vector2i(2,5),
	 exits=[
		{"dir":"north","tile":Vector2i(2,1),"porch":Vector2i(2,0)},
		{"dir":"east","tile":Vector2i(3,2),"porch":Vector2i(4,2)},
		{"dir":"west","tile":Vector2i(1,2),"porch":Vector2i(0,2)},
	]},

	# 1: The Fork — 2x2, exits N+E (2 choices)
	{floor=[
		Vector2i(1,2),Vector2i(2,2),
		Vector2i(1,3),Vector2i(2,3),
	], corridor=[Vector2i(1,4)], entrance=Vector2i(1,5),
	 exits=[
		{"dir":"north","tile":Vector2i(1,2),"porch":Vector2i(1,1)},
		{"dir":"east","tile":Vector2i(2,2),"porch":Vector2i(3,2)},
	]},

	# 2: The Straight — 1-wide, 4 tall, exit N (narrow corridor)
	{floor=[
		Vector2i(1,1),Vector2i(1,2),Vector2i(1,3),Vector2i(1,4),
	], corridor=[Vector2i(1,5)], entrance=Vector2i(1,6),
	 exits=[
		{"dir":"north","tile":Vector2i(1,1),"porch":Vector2i(1,0)},
	]},

	# 3: Start Room — 3x2, exits N+E+W (entry chamber)
	{floor=[
		Vector2i(1,3),Vector2i(2,3),Vector2i(3,3),
		Vector2i(1,4),Vector2i(2,4),Vector2i(3,4),
	], corridor=[Vector2i(2,5)], entrance=Vector2i(2,6),
	 exits=[
		{"dir":"north","tile":Vector2i(2,3),"porch":Vector2i(2,2)},
		{"dir":"east","tile":Vector2i(3,3),"porch":Vector2i(4,3)},
		{"dir":"west","tile":Vector2i(1,3),"porch":Vector2i(0,3)},
	]},

	# 4: The Pillar — 3x3 with blocked center, exit W (walk around)
	{floor=[
		Vector2i(1,1),Vector2i(2,1),Vector2i(3,1),
		Vector2i(1,2),              Vector2i(3,2),
		Vector2i(1,3),Vector2i(2,3),Vector2i(3,3),
	], corridor=[Vector2i(3,4)], entrance=Vector2i(3,5),
	 exits=[
		{"dir":"west","tile":Vector2i(1,1),"porch":Vector2i(0,1)},
	]},

	# 5: The Arena — 4x3 wide, exits E+W (big battle space)
	{floor=[
		Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),Vector2i(4,2),
		Vector2i(1,3),Vector2i(2,3),Vector2i(3,3),Vector2i(4,3),
		Vector2i(1,4),Vector2i(2,4),Vector2i(3,4),Vector2i(4,4),
	], corridor=[Vector2i(3,5)], entrance=Vector2i(3,6),
	 exits=[
		{"dir":"east","tile":Vector2i(4,3),"porch":Vector2i(5,3)},
		{"dir":"west","tile":Vector2i(1,4),"porch":Vector2i(0,4)},
	]},

	# 6: The Dead End — 2x2, NO exits (compact, claustrophobic)
	{floor=[
		Vector2i(1,2),Vector2i(2,2),
		Vector2i(1,3),Vector2i(2,3),
	], corridor=[Vector2i(1,4)], entrance=Vector2i(1,5),
	 exits=[]},

	# 7: The Treasury — 3x3, NO exits (large dead-end, rich loot)
	{floor=[
		Vector2i(1,1),Vector2i(2,1),Vector2i(3,1),
		Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),
		Vector2i(1,3),Vector2i(2,3),Vector2i(3,3),
	], corridor=[Vector2i(2,4)], entrance=Vector2i(2,5),
	 exits=[]},

	# 8: The Cross — 3x3, exits N+E+W (unique porches, no collisions)
	{floor=[
		Vector2i(1,1),Vector2i(2,1),Vector2i(3,1),
		Vector2i(1,2),Vector2i(2,2),Vector2i(3,2),
		Vector2i(1,3),Vector2i(2,3),Vector2i(3,3),
	], corridor=[Vector2i(2,4)], entrance=Vector2i(2,5),
	 exits=[
		{"dir":"north","tile":Vector2i(3,1),"porch":Vector2i(3,0)},
		{"dir":"east","tile":Vector2i(3,1),"porch":Vector2i(4,1)},
		{"dir":"west","tile":Vector2i(1,1),"porch":Vector2i(0,0)},
	]},

	# 9: The Gauntlet — 2-wide, 5 tall, exit N (long tense corridor)
	{floor=[
		Vector2i(1,0),Vector2i(2,0),
		Vector2i(1,1),Vector2i(2,1),
		Vector2i(1,2),Vector2i(2,2),
		Vector2i(1,3),Vector2i(2,3),
		Vector2i(1,4),Vector2i(2,4),
	], corridor=[Vector2i(1,5)], entrance=Vector2i(1,6),
	 exits=[
		{"dir":"north","tile":Vector2i(1,0),"porch":Vector2i(1,-1)},
	]},
]


func _ready() -> void: randomize()


func generate_single(template_idx: int) -> Dictionary:
	var defn: Dictionary = ROOMS[template_idx]
	var tiles: Array = []

	for f in defn["floor"]:
		tiles.append(f)

	for c in defn["corridor"]:
		tiles.append(c)

	var ent: Vector2i = defn["entrance"] as Vector2i
	tiles.append(ent)

	var exits: Array = []
	for ex in defn["exits"]:
		var ed: Dictionary = ex as Dictionary
		var et: Vector2i = ed["tile"] as Vector2i
		var porch: Vector2i = ed["porch"] as Vector2i
		tiles.append(et)
		tiles.append(porch)
		exits.append({"dir": ed["dir"], "tile": et, "porch": porch})

	# Center from floor tiles
	var cx: int = 0; var cy: int = 0; var floor_count: int = 0
	for t in defn["floor"]:
		var tv: Vector2i = t as Vector2i
		cx += tv.x; cy += tv.y; floor_count += 1
	var center: Vector2i = Vector2i(cx / floor_count, cy / floor_count)
	if not defn["floor"].has(center):
		var best_dist: int = 9999
		var best_tile: Vector2i = Vector2i.ZERO
		for ft in defn["floor"]:
			var fv: Vector2i = ft as Vector2i
			var d: int = (fv - center).length_squared()
			if d < best_dist: best_dist = d; best_tile = fv
		center = best_tile

	return {
		"tiles": tiles, "exits": exits, "entrance": ent,
		"center": center, "template_idx": template_idx,
	}
