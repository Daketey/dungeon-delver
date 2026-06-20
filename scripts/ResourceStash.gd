extends Node
## Player-persistent state singleton. Tracks inventory, gold, kill count,
## equipment slots, and derives active stat bonuses from equipped items.

# -- Currency --
var gold: int = 0

# -- Items --
var inventory: Array[Dictionary] = []

# -- Equipment slots --
enum Slot { WEAPON, OFFHAND, ARMOR, ACCESSORY }
var equipped: Dictionary = {
	Slot.WEAPON: null,
	Slot.OFFHAND: null,
	Slot.ARMOR: null,
	Slot.ACCESSORY: null,
}

# -- Kill tracking --
var kill_count: int = 0
var boss_active: bool = false

# -- Temporary buffs (2-use scrolls) --
var temp_buffs: Dictionary = {}  # {"defense_plus1": uses, "damage_plus1": uses}

# -- Derived stats --
var bonus_damage: int = 0
var bonus_defense: int = 0
var bonus_hit: int = 0
var bonus_heroic_feats: int = 0
var trap_damage_reduction: int = 0
var blocks_shield: bool = false
var reroll_attack: bool = false
var crit_bonus: int = 0


func add_item(item: Dictionary) -> void:
	inventory.append(item.duplicate())


func remove_item(index: int) -> Dictionary:
	if index < 0 or index >= inventory.size():
		return {}
	return inventory.pop_at(index)


func add_gold(amount: int) -> void:
	gold += amount


func spend_gold(amount: int) -> bool:
	if gold < amount:
		return false
	gold -= amount
	return true


func has_item(item_name: String) -> bool:
	for item in inventory:
		if item.get("name") == item_name:
			return true
	return false


func equip(item_index: int) -> bool:
	if item_index < 0 or item_index >= inventory.size():
		return false
	var item: Dictionary = inventory[item_index]
	var slot_name: String = item.get("slot", "")
	if slot_name.is_empty():
		return false  # Not equippable

	var target_slot: int = _slot_from_name(slot_name)
	if target_slot < 0:
		return false

	# Longsword blocks shields
	if target_slot == Slot.OFFHAND and item.get("effect", "") == "defense_bonus":
		if equipped[Slot.WEAPON] != null and equipped[Slot.WEAPON].get("blocks_shield", false):
			return false
	if target_slot == Slot.WEAPON and item.get("blocks_shield", false):
		if equipped[Slot.OFFHAND] != null and equipped[Slot.OFFHAND].get("effect", "") == "defense_bonus":
			unequip(Slot.OFFHAND)

	# Unequip current item in that slot
	if equipped[target_slot] != null:
		inventory.append(equipped[target_slot])

	# Equip the new item
	equipped[target_slot] = item.duplicate()
	inventory.remove_at(item_index)
	_recalc_stats()
	return true


func unequip(slot: int) -> bool:
	if equipped[slot] == null:
		return false
	inventory.append(equipped[slot])
	equipped[slot] = null
	_recalc_stats()
	return true


func is_equipped(item_index: int) -> bool:
	return false  # Equipped items are removed from inventory, so never by index


func _slot_from_name(slot_name: String) -> int:
	match slot_name:
		"weapon":   return Slot.WEAPON
		"offhand":  return Slot.OFFHAND
		"armor":    return Slot.ARMOR
		"accessory":return Slot.ACCESSORY
	return -1


static func slot_name(slot: int) -> String:
	match slot:
		Slot.WEAPON:    return "Weapon"
		Slot.OFFHAND:   return "Offhand"
		Slot.ARMOR:     return "Armor"
		Slot.ACCESSORY: return "Accessory"
	return ""


func _recalc_stats() -> void:
	bonus_damage = 0
	bonus_defense = 0
	bonus_hit = 0
	bonus_heroic_feats = 0
	trap_damage_reduction = 0
	blocks_shield = false
	reroll_attack = false
	crit_bonus = 0

	for slot_key in equipped.keys():
		var item = equipped[slot_key]
		if item == null:
			continue
		var effect: String = item.get("effect", "")
		match effect:
			"defense_bonus":
				bonus_defense += 1
				blocks_shield = true
			"defense_plus1_2uses":
				bonus_defense += 1
			"damage_plus1_2uses":
				bonus_damage += 1
			"defense_plus1_trapresist":
				bonus_defense += 1
				trap_damage_reduction += 1
			"heroic_feat_plus1":
				bonus_heroic_feats += 1
			"hit_plus1":
				bonus_hit += 1

	# Also account for weapon damage bonus
	if equipped[Slot.WEAPON] != null:
		bonus_damage += equipped[Slot.WEAPON].get("damage_bonus", 0)

	# Temp buffs from scrolls (2-use)
	if temp_buffs.get("defense_plus1", 0) > 0:
		bonus_defense += 1
	if temp_buffs.get("damage_plus1", 0) > 0:
		bonus_damage += 1


func get_equipped_name(slot: int) -> String:
	if equipped[slot] != null:
		return equipped[slot].get("name", "")
	return "-"
