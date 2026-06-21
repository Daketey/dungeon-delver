extends CanvasLayer
## Inventory and equipment management screen. Press Tab to toggle.

const DiceOverlayScene = preload("res://scenes/DiceOverlay.tscn")

@onready var panel: Panel = $Panel
@onready var gold_label: Label = $Panel/MainVBox/GoldLabel
@onready var equip_grid: GridContainer = $Panel/MainVBox/EquipmentGrid
@onready var stat_label: Label = $Panel/MainVBox/StatLabel/Stat
@onready var item_list: ItemList = $Panel/MainVBox/ItemList
@onready var use_btn: Button = $Panel/MainVBox/ButtonRow/UseBtn
@onready var equip_btn: Button = $Panel/MainVBox/ButtonRow/EquipBtn
@onready var drop_btn: Button = $Panel/MainVBox/ButtonRow/DropBtn
@onready var close_btn: Button = $Panel/MainVBox/ButtonRow/CloseBtn

# Quick lookup: slot index -> item Label
var _slot_item_labels: Array[Label] = []
var _pending_use: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	visible = false

	# Size and position the panel
	#panel.size = Vector2(480, 460)
	#var vp: Rect2 = get_viewport().get_visible_rect()
	#panel.position = (vp.size - panel.size) * 0.5

	#var bg: ColorRect = $Panel/Background
	#bg.size = panel.size

	#var vbox: VBoxContainer = $Panel/MainVBox
	#vbox.position = Vector2(12, 12)
	#vbox.size = panel.size - Vector2(24, 24)

	# Collect item labels per slot for quick refresh access
	for slot in range(4):
		var slot_vbox := equip_grid.get_child(slot)
		var item_lbl := slot_vbox.get_node("ItemLabel") as Label
		_slot_item_labels.append(item_lbl)
		# Connect unequip button with captured slot index
		var unequip_btn := slot_vbox.get_node("UnequipBtn") as Button
		var s: int = slot
		unequip_btn.connect("pressed", func(): _on_unequip(s))


func _panel_center() -> void:
	var vp: Rect2 = get_viewport().get_visible_rect()
	panel.position = (vp.size - panel.size) * 0.5


func open() -> void:
	AudioManager.play("inventory_open")
	_panel_center()
	visible = true
	_refresh()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close() -> void:
	AudioManager.play("inventory_close")
	visible = false
	get_tree().paused = false
	if not _is_combat_active():
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("inventory"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	gold_label.text = "Gold: %d GP" % ResourceStash.gold

	for slot in range(4):
		if slot < _slot_item_labels.size():
			_slot_item_labels[slot].text = ResourceStash.get_equipped_name(slot)

	var lines: Array[String] = []
	var bd: int = ResourceStash.bonus_damage
	var bf: int = ResourceStash.bonus_defense
	var bh: int = ResourceStash.bonus_hit
	var bfe: int = ResourceStash.bonus_heroic_feats
	var tr: int = ResourceStash.trap_damage_reduction
	if bd != 0: lines.append("Damage +%d" % bd)
	if bf != 0: lines.append("Defense +%d" % bf)
	if bh != 0: lines.append("Hit +%d" % bh)
	if bfe != 0: lines.append("Heroic Feats +%d" % bfe)
	if tr != 0: lines.append("Trap Resist -%d" % tr)
	# Show temp buffs
	if ResourceStash.temp_buffs.get("defense_plus1", 0) > 0:
		lines.append("Stoneskin (%d uses)" % ResourceStash.temp_buffs["defense_plus1"])
	if ResourceStash.temp_buffs.get("damage_plus1", 0) > 0:
		lines.append("Strength (%d uses)" % ResourceStash.temp_buffs["damage_plus1"])
	stat_label.text = "Bonuses: " + (", ".join(lines) if lines.size() > 0 else "None")

	item_list.clear()
	for i in range(ResourceStash.inventory.size()):
		var item: Dictionary = ResourceStash.inventory[i]
		var txt: String = item.get("name", "?")
		var gp: int = item.get("gp", 0)
		var slot_name: String = item.get("slot", "")
		if not slot_name.is_empty():
			txt += "  [%s]" % slot_name
		if gp > 0:
			txt += "  (%d GP)" % gp
		if item.get("consumable", false):
			txt += "  [Use]"
		item_list.add_item(txt)

	use_btn.disabled = true
	equip_btn.disabled = true
	drop_btn.disabled = true


func _on_item_selected(index: int) -> void:
	if index < 0 or index >= ResourceStash.inventory.size():
		return
	var item: Dictionary = ResourceStash.inventory[index]
	var consumable: bool = item.get("consumable", false)
	var has_slot: bool = not item.get("slot", "").is_empty()
	use_btn.disabled = not consumable
	equip_btn.disabled = not has_slot
	drop_btn.disabled = false


func _on_use_pressed() -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	if idx < 0 or idx >= ResourceStash.inventory.size():
		return
	var item: Dictionary = ResourceStash.inventory[idx]
	var effect: String = item.get("effect", "")
	var item_name: String = item.get("name", "")

	var player := _find_player()
	var cm := _find_combat_manager()

	match effect:
		"heal_d4":
			_pending_use = {"idx": idx, "effect": effect, "item_name": item_name}
			visible = false
			get_tree().paused = false
			_show_dice_overlay(4, "Roll to heal")
			return
		"heal_d8":
			_pending_use = {"idx": idx, "effect": effect, "item_name": item_name}
			visible = false
			get_tree().paused = false
			_show_dice_overlay(8, "Roll to heal")
			return
		"max_hp_plus1_fullheal":
			if player:
				player.max_health += 1
				player.health = player.max_health
				_show_flash("Max HP +1! Fully healed.", Color.GOLD)
		"teleport":
			# Cannot escape the boss fight
			if cm and cm.is_boss_fight():
				_show_flash("The dark energy anchors you here!", Color.RED)
				return
			# End combat if active, then teleport to entrance
			if cm and cm.is_active():
				cm.cancel()
			var cs := get_parent().get_node_or_null("CombatScreen") as CombatScreen
			if cs:
				cs.visible = false
			var world := get_parent()
			if world and world.has_method("teleport_player_to_entrance"):
				close()
				if player:
					player.combat_active = false
				world.teleport_player_to_entrance()
				return
		"paralysis":
			if cm and cm.is_active():
				cm.apply_paralysis()
				_show_flash("Enemy paralyzed!", Color.CYAN)
			else:
				_show_flash("Can only use in combat!", Color.ORANGE)
				return  # Don't consume
		"damage_d4plus2":
			if cm and cm.is_active():
				_pending_use = {"idx": idx, "effect": effect, "item_name": item_name}
				visible = false
				get_tree().paused = false
				_show_dice_overlay(4, "Damage = roll + 2")
				return
			else:
				_show_flash("Can only use in combat!", Color.ORANGE)
				return  # Don't consume
		"defense_plus1_2uses":
			if ResourceStash.temp_buffs.get("defense_plus1", 0) > 0:
				_show_flash("Stoneskin is already active!", Color.ORANGE)
				return  # Don't consume
			ResourceStash.temp_buffs["defense_plus1"] = 2
			ResourceStash._recalc_stats()
			_show_flash("Stoneskin: +1 Defense for 2 combats.", Color.CYAN)
		"damage_plus1_2uses":
			if ResourceStash.temp_buffs.get("damage_plus1", 0) > 0:
				_show_flash("Strength scroll is already active!", Color.ORANGE)
				return  # Don't consume
			ResourceStash.temp_buffs["damage_plus1"] = 2
			ResourceStash._recalc_stats()
			_show_flash("Strength: +1 Damage for 2 combats.", Color.CYAN)
		_:
			_show_flash("%s used." % item_name, Color.WHITE)

	AudioManager.play("item_use")
	ResourceStash.remove_item(idx)
	_refresh()


func _show_flash(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, panel.position.y + panel.size.y + 8)
	lbl.size = Vector2(get_viewport().get_visible_rect().size.x, 24)
	add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 1.5).set_delay(0.5)
	tween.tween_callback(lbl.queue_free)


func _show_dice_overlay(sides: int, context: String) -> void:
	var overlay := DiceOverlayScene.instantiate()
	get_tree().root.add_child(overlay)
	overlay.roll_result.connect(_on_consumable_roll_result)
	overlay.open(sides, context)


func _on_consumable_roll_result(value: int) -> void:
	var idx: int = _pending_use.get("idx", -1)
	var effect: String = _pending_use.get("effect", "")
	var item_name: String = _pending_use.get("item_name", "item")
	_pending_use = {}

	var player := _find_player()
	var cm := _find_combat_manager()

	match effect:
		"heal_d4":
			if player:
				player.health = min(player.max_health, player.health + value)
				_show_flash("Healed %d HP!" % value, Color.GREEN)
		"heal_d8":
			if player:
				player.health = min(player.max_health, player.health + value)
				_show_flash("Healed %d HP!" % value, Color.GREEN)
		"damage_d4plus2":
			if cm and cm.is_active():
				var dmg: int = value + 2
				cm.apply_lightning_with_roll(dmg)
				_show_flash("Lightning deals %d damage!" % dmg, Color.YELLOW)

	AudioManager.play("item_use")
	if idx >= 0 and idx < ResourceStash.inventory.size():
		ResourceStash.remove_item(idx)

	# Reopen inventory
	visible = true
	_refresh()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func _on_equip_pressed() -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	AudioManager.play("weapon_equip")
	ResourceStash.equip(idx)
	_refresh()


func _on_drop_pressed() -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
	ResourceStash.remove_item(idx)
	_refresh()


func _on_unequip(slot: int) -> void:
	ResourceStash.unequip(slot)
	_refresh()


func _find_player() -> GridPlayer:
	var root := get_tree().get_root()
	if root:
		var p := root.get_node_or_null("World3/Player")
		if p and p is GridPlayer: return p as GridPlayer
	return null


func _find_combat_manager() -> CombatManager:
	var parent := get_parent()
	if parent:
		var cm := parent.get_node_or_null("CombatManager")
		if cm and cm is CombatManager: return cm as CombatManager
	return null


func _is_combat_active() -> bool:
	var cm := _find_combat_manager()
	return cm != null and cm.is_active()
