extends StaticBody3D
class_name TreasureChest

## Treasure data from GameData.TREASURES entry
var treasure_data: Dictionary = {}
var collected: bool = false

func init_from_data(data: Dictionary) -> void:
	treasure_data = data.duplicate()
	name = "TreasureChest"

## Collect the treasure. Returns {success, treasure, message, gp}.
func collect() -> Dictionary:
	if collected:
		return {"success": false, "message": "Already collected."}
	collected = true
	return {
		"success": true,
		"treasure": treasure_data.duplicate(),
		"message": "You found %s!" % treasure_data.get("name", "treasure"),
		"gp": treasure_data.get("gp", 0),
	}
