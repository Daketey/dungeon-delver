extends StaticBody3D
class_name TrapPlaceholder

## Trap data from GameData.TRAPS entry
var trap_data: Dictionary = {}
var activated: bool = false

func init_from_data(data: Dictionary) -> void:
	trap_data = data.duplicate()
	name = data.get("name", "Trap")


## Resolve trap effect. If player_roll (1-8) is provided from DiceOverlay,
## uses the d8 table. Otherwise auto-rolls d6 internally (legacy fallback).
func resolve(player_roll: int = -1) -> Dictionary:
	if activated:
		return {"evaded": true, "damage": 0, "message": "Already triggered."}
	activated = true

	var trap_name: String = trap_data.get("name", "Trap")

	if player_roll >= 1 and player_roll <= 8:
		return _resolve_d8(player_roll, trap_name)

	# Legacy d6 auto-roll
	var evade_roll: int = GameData.roll(6)
	var save: int = trap_data.get("save", 5)
	var evaded: bool = evade_roll >= save

	if evaded:
		return {
			"evaded": true, "damage": 0, "evade_roll": evade_roll,
			"message": "You evaded the %s! (rolled %d, needed %d+)" % [trap_name, evade_roll, save]
		}

	if trap_data.get("teleport", false):
		var rooms_back: int = GameData.roll(4)
		return {
			"evaded": false, "damage": 0, "evade_roll": evade_roll,
			"teleport_rooms": rooms_back,
			"message": "The %s teleports you %d rooms back!" % [trap_name, rooms_back]
		}

	var damage: int = trap_data.get("damage", 2)
	return {
		"evaded": false, "damage": damage, "evade_roll": evade_roll,
		"message": "The %s hits you for %d damage! (rolled %d, needed %d+)" % [trap_name, damage, evade_roll, save]
	}


## Player-driven d8 roll: 1-2 full, 3-5 half, 6-7 quarter, 8 evaded.
func _resolve_d8(roll_val: int, trap_name: String) -> Dictionary:
	if trap_data.get("teleport", false):
		if roll_val <= 4:
			var rooms_back: int = GameData.roll(4)
			return {"evaded": false, "damage": 0, "evade_roll": roll_val,
				"teleport_rooms": rooms_back,
				"message": "The %s teleports you %d rooms back! (rolled %d)" % [trap_name, rooms_back, roll_val]}
		elif roll_val <= 7:
			return {"evaded": true, "damage": 0, "evade_roll": roll_val,
				"message": "You resist the %s pull! (rolled %d)" % [trap_name, roll_val]}
		else:
			return {"evaded": true, "damage": 0, "evade_roll": roll_val,
				"message": "You completely evade the %s! (rolled 8!)" % trap_name}

	var base_damage: int = trap_data.get("damage", 2)
	match roll_val:
		1, 2:
			return {"evaded": false, "damage": base_damage, "evade_roll": roll_val,
				"message": "The %s hits you for %d damage! (rolled %d)" % [trap_name, base_damage, roll_val]}
		3, 4, 5:
			var half: int = max(1, int(base_damage * 0.5))
			return {"evaded": false, "damage": half, "evade_roll": roll_val,
				"message": "You partially dodge the %s -- %d damage. (rolled %d)" % [trap_name, half, roll_val]}
		6, 7:
			var quarter: int = max(0, int(base_damage * 0.25))
			return {"evaded": false, "damage": quarter, "evade_roll": roll_val,
				"message": "You narrowly avoid the %s -- %d damage. (rolled %d)" % [trap_name, quarter, roll_val]}
		_:
			return {"evaded": true, "damage": 0, "evade_roll": roll_val,
				"message": "You completely evade the %s! (rolled 8!)" % trap_name}
