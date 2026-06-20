extends StaticBody3D
class_name TrapPlaceholder

## Trap data from GameData.TRAPS entry
var trap_data: Dictionary = {}
var activated: bool = false

func init_from_data(data: Dictionary) -> void:
	trap_data = data.duplicate()
	name = data.get("name", "Trap")

## Roll evasion and apply effects. Returns a result dictionary:
## {evaded: bool, damage: int, message: String, teleport_rooms?: int}
func resolve() -> Dictionary:
	if activated:
		return {"evaded": true, "damage": 0, "message": "Already triggered."}
	activated = true

	var evade_roll: int = GameData.roll(6)
	var save: int = trap_data.get("save", 5)
	var evaded: bool = evade_roll >= save
	var trap_name: String = trap_data.get("name", "Trap")

	if evaded:
		return {
			"evaded": true, "damage": 0, "evade_roll": evade_roll,
			"message": "You evaded the %s! (rolled %d, needed %d+)" % [trap_name, evade_roll, save]
		}

	# Not evaded — apply effect
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
