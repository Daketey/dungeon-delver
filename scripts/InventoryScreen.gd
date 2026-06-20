extends CanvasLayer
## Inventory and equipment management screen. Press Tab to toggle.

var panel: Panel
var gold_label: Label
var equip_grid: GridContainer
var stat_label: Label
var item_list: ItemList
var use_btn: Button
var equip_btn: Button
var drop_btn: Button
var close_btn: Button

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	visible = false
	_build_ui()


func _build_ui() -> void:
	panel = Panel.new()
	panel.size = Vector2(480, 460)
	var vp: Rect2 = get_viewport().get_visible_rect()
	panel.position = (vp.size - panel.size) * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var ibg := ColorRect.new(); ibg.color = Color(0.08, 0.08, 0.12, 0.95); ibg.size = panel.size; panel.add_child(ibg)
	add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	vbox.position = Vector2(12, 12)
	vbox.size = panel.size - Vector2(24, 24)
	panel.add_child(vbox)

	gold_label = _lbl("Gold: 0 GP", 16)
	gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	vbox.add_child(gold_label)

	var eq_label := _lbl("Equipment", 16)
	vbox.add_child(eq_label)
	equip_grid = GridContainer.new()
	equip_grid.columns = 4
	equip_grid.add_theme_constant_override("h_separation", 6)
	vbox.add_child(equip_grid)
	for slot in range(4):
		var slot_vbox := VBoxContainer.new()
		var slot_lbl := _lbl(ResourceStash.slot_name(slot), 12)
		slot_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		slot_vbox.add_child(slot_lbl)
		var item_lbl := _lbl("-", 13)
		item_lbl.name = "slot_%d" % slot
		slot_vbox.add_child(item_lbl)
		var unequip_btn := _btn("X", 30)
		var s: int = slot
		unequip_btn.connect("pressed", func(): _on_unequip(s))
		slot_vbox.add_child(unequip_btn)
		equip_grid.add_child(slot_vbox)

	stat_label = _lbl("", 13)
	vbox.add_child(stat_label)

	vbox.add_child(_lbl("Inventory", 16))
	item_list = ItemList.new()
	item_list.custom_minimum_size = Vector2(0, 160)
	item_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	item_list.allow_reselect = true
	item_list.connect("item_selected", Callable(self, "_on_item_selected"))
	vbox.add_child(item_list)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 6)
	vbox.add_child(btn_row)

	use_btn = _btn("Use", 90)
	use_btn.disabled = true
	use_btn.connect("pressed", Callable(self, "_on_use_pressed"))
	btn_row.add_child(use_btn)

	equip_btn = _btn("Equip", 90)
	equip_btn.disabled = true
	equip_btn.connect("pressed", Callable(self, "_on_equip_pressed"))
	btn_row.add_child(equip_btn)

	drop_btn = _btn("Drop", 90)
	drop_btn.disabled = true
	drop_btn.connect("pressed", Callable(self, "_on_drop_pressed"))
	btn_row.add_child(drop_btn)

	close_btn = _btn("Close (Tab)", 100)
	close_btn.connect("pressed", Callable(self, "close"))
	btn_row.add_child(close_btn)


func open() -> void:
	visible = true
	_refresh()
	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func close() -> void:
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
		var item_lbl := equip_grid.get_child(slot).get_node("slot_%d" % slot) as Label
		if item_lbl:
			item_lbl.text = ResourceStash.get_equipped_name(slot)

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
			if player:
				var amt := randi() % 4 + 1
				player.health = min(player.max_health, player.health + amt)
				_show_flash("Healed %d HP!" % amt, Color.GREEN)
		"heal_d8":
			if player:
				var amt := randi() % 8 + 1
				player.health = min(player.max_health, player.health + amt)
				_show_flash("Healed %d HP!" % amt, Color.GREEN)
		"max_hp_plus1_fullheal":
			if player:
				player.max_health += 1
				player.health = player.max_health
				_show_flash("Max HP +1! Fully healed.", Color.GOLD)
		"teleport":
			# Teleport to dungeon entrance
			var world := get_parent()
			if world and world.has_method("teleport_player_to_entrance"):
				close()
				ResourceStash.remove_item(idx)
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
				var dmg: int = cm.apply_lightning()
				_show_flash("Lightning deals %d damage!" % dmg, Color.YELLOW)
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


func _on_equip_pressed() -> void:
	var selected := item_list.get_selected_items()
	if selected.is_empty():
		return
	var idx: int = selected[0]
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


func _lbl(text: String, sz: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", sz)
	return l


func _btn(text: String, w: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(w, 30)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	return b
