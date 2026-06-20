extends Node
## Simple Dungeon 1.5 rulebook tables. Autoload.

func roll(sides: int) -> int:
	return randi() % sides + 1

# =====================================================================
# Room Contents table (d8)
# =====================================================================
const ROOM_CONTENTS: Dictionary = {
	1: {"type": "strong_enemy"},
	2: {"type": "enemy"},
	3: {"type": "trap"},
	4: {"type": "messy", "sub_die": 6, "sub_table": {1:"enemy",2:"enemy",3:"trap",4:"trap",5:"gold",6:"gold"}},
	5: {"type": "messy", "sub_die": 6, "sub_table": {1:"enemy",2:"trap",3:"trap",4:"gold",5:"treasure",6:"treasure"}},
	6: {"type": "messy", "sub_die": 6, "sub_table": {1:"trap",2:"trap",3:"gold",4:"gold",5:"treasure",6:"treasure"}},
	7: {"type": "healing_spring"},
	8: {"type": "store_room"},
}

# =====================================================================
# Enemies table (d6)
# =====================================================================
const ENEMIES: Dictionary = {
	1: {"name":"Tunnel Wyrm","level":4,"attack":2,"defense":1,"hp":8,"treasure_min":3,"sprite":"res://Enemies/tunnel_wyrm.png","sprite_scale":1.0},
	2: {"name":"Lesser Demon","level":4,"attack":1,"defense":1,"hp":6,"treasure_min":4,"sprite":"res://Enemies/lesser_demon.png","sprite_scale":0.9},
	3: {"name":"Cave Giant","level":3,"attack":1,"defense":2,"hp":8,"treasure_min":4,"sprite":"res://Enemies/cave_giant.png","sprite_scale":1.0},
	4: {"name":"Giant Centipede","level":3,"attack":1,"defense":1,"hp":6,"treasure_min":4,"sprite":"res://Enemies/giant_centripede.png","sprite_scale":1.2},
	5: {"name":"Barrow Wight","level":3,"attack":0,"defense":0,"hp":6,"treasure_min":5,"sprite":"res://Enemies/barrow_wight.png","sprite_scale":0.9},
	6: {"name":"Goblin","level":2,"attack":-1,"defense":-1,"hp":4,"treasure_min":6,"sprite":"res://Enemies/goblin.png","sprite_scale":0.8},
}

# =====================================================================
# Traps table (d4)
# =====================================================================
const TRAPS: Dictionary = {
	1: {"name":"Trap-door","save":5,"damage":3},
	2: {"name":"Spike pit","save":5,"damage":2},
	3: {"name":"Pit","save":4,"damage":2},
	4: {"name":"Teleport","save":5,"teleport":true},
}

# =====================================================================
# Treasure table (d12)
# =====================================================================
const TREASURES: Dictionary = {
	1:  {"name":"Potion","effect":"heal_d4","gp":3,"consumable":true},
	2:  {"name":"Teleport scroll","effect":"teleport","gp":2,"consumable":true},
	3:  {"name":"Paralysis scroll","effect":"paralysis","gp":4,"consumable":true},
	4:  {"name":"Shield","effect":"defense_bonus","gp":6,"slot":"offhand"},
	5:  {"name":"Lightning scroll","effect":"damage_d4plus2","gp":4,"consumable":true},
	6:  {"name":"Large potion","effect":"heal_d8","gp":5,"consumable":true},
	7:  {"name":"Stoneskin scroll","effect":"defense_plus1_2uses","gp":5,"consumable":true},
	8:  {"name":"Strength scroll","effect":"damage_plus1_2uses","gp":5,"consumable":true},
	9:  {"name":"Holy blessing","effect":"max_hp_plus1_fullheal","gp":-1,"consumable":true},
	10: {"name":"Armour","effect":"defense_plus1_trapresist","gp":8,"slot":"armor"},
	11: {"name":"Heroic amulet","effect":"heroic_feat_plus1","gp":8,"slot":"accessory"},
	12: {"name":"Mastery amulet","effect":"hit_plus1","gp":10,"slot":"accessory"},
}

# =====================================================================
# Weapons table (d6)
# =====================================================================
const WEAPONS: Dictionary = {
	1: {"name":"Dagger","damage_bonus":0,"gp":2},
	2: {"name":"Sword","damage_bonus":1,"gp":3},
	3: {"name":"Flail","damage_bonus":1,"reroll_attack":true,"gp":4},
	4: {"name":"Longsword","damage_bonus":2,"blocks_shield":true,"gp":5},
	5: {"name":"War Hammer","damage_bonus":2,"gp":8},
	6: {"name":"Mace","damage_bonus":2,"crit_bonus":1,"gp":10},
}

# =====================================================================
# Boss
# =====================================================================
const BOSS: Dictionary = {
	"name":"Greater Demon","level":5,"attack":2,"defense":2,"hp":10,"treasure_min":2,
	"sprite":"res://Enemies/greater_demon.png","sprite_scale":1.15,
	"special_name":"Infernal Flame",
	"special_desc":"Natural 1 on hit die deals 4 damage instantly",
}

# =====================================================================
# Composite roll functions
# =====================================================================

func roll_room_contents() -> Dictionary:
	var r: int = roll(8)
	var entry: Dictionary = ROOM_CONTENTS[r].duplicate()
	var result: Dictionary = {"primary": entry["type"], "d8_roll": r}

	match result["primary"]:
		"enemy":
			result["enemy"] = ENEMIES[roll(6)].duplicate()
		"strong_enemy":
			result["enemy"] = ENEMIES[roll(4)].duplicate()
			result["enemy"]["is_strong"] = true
		"trap":
			result["trap"] = TRAPS[roll(4)].duplicate()
		"messy":
			var sub_r: int = roll(entry["sub_die"])
			result["messy_d6"] = sub_r
			if entry["sub_table"].has(sub_r):
				var sub_type: String = entry["sub_table"][sub_r]
				result["sub_type"] = sub_type
				match sub_type:
					"enemy":
						result["enemy"] = ENEMIES[roll(6)].duplicate()
					"trap":
						result["trap"] = TRAPS[roll(4)].duplicate()
					"treasure":
						result["treasure"] = TREASURES[roll(12)].duplicate()
					"gold":
						result["gold_amount"] = roll(6)
		"healing_spring": pass
		"store_room":
			result["treasure"] = TREASURES[roll(12)].duplicate()

	return result


func roll_enemy() -> Dictionary:
	return ENEMIES[roll(6)].duplicate()

func roll_treasure() -> Dictionary:
	return TREASURES[roll(12)].duplicate()
