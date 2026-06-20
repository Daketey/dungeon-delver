extends CanvasLayer
## Merchant buy/sell screen. Opened by interacting with the merchant (E key).

var panel: Panel
var player_gold_label: Label
var shop_gold_label: Label
var buy_list: ItemList
var sell_list: ItemList
var buy_btn: Button
var sell_btn: Button
var close_btn: Button
var merchant_inventory: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 60
	visible = false
	_generate_shop_inventory()
	_build_ui()


func _generate_shop_inventory() -> void:
	merchant_inventory.clear()
	for _i in range(2):
		var w: Dictionary = GameData.WEAPONS[GameData.roll(6)].duplicate()
		w["is_weapon"] = true
		w["slot"] = "weapon"
		merchant_inventory.append(w)
	for _i in range(2):
		var t: Dictionary = GameData.TREASURES[GameData.roll(12)].duplicate()
		merchant_inventory.append(t)
	merchant_inventory.append(GameData.TREASURES[1].duplicate())


func _build_ui() -> void:
	panel = Panel.new()
	panel.size = Vector2(560, 420)
	var vp: Rect2 = get_viewport().get_visible_rect()
	panel.position = (vp.size - panel.size) * 0.5
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var sbg := ColorRect.new(); sbg.color = Color(0.08, 0.08, 0.12, 0.95); sbg.size = panel.size; panel.add_child(sbg)
	add_child(panel)

	var main_hbox := HBoxContainer.new()
	main_hbox.add_theme_constant_override("separation", 12)
	main_hbox.position = Vector2(12, 12)
	main_hbox.size = panel.size - Vector2(24, 24)
	panel.add_child(main_hbox)

	var buy_vbox := VBoxContainer.new()
	buy_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(buy_vbox)

	buy_vbox.add_child(_lbl("Merchant's Wares", 16))
	buy_list = ItemList.new()
	buy_list.custom_minimum_size = Vector2(0, 260)
	buy_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	buy_list.connect("item_selected", Callable(self, "_on_buy_selected"))
	buy_vbox.add_child(buy_list)
	shop_gold_label = _lbl("", 13)
	shop_gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	buy_vbox.add_child(shop_gold_label)
	buy_btn = _btn("Buy", 100)
	buy_btn.disabled = true
	buy_btn.connect("pressed", Callable(self, "_on_buy_pressed"))
	buy_vbox.add_child(buy_btn)

	var sell_vbox := VBoxContainer.new()
	sell_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main_hbox.add_child(sell_vbox)

	sell_vbox.add_child(_lbl("Your Items", 16))
	sell_list = ItemList.new()
	sell_list.custom_minimum_size = Vector2(0, 260)
	sell_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sell_list.connect("item_selected", Callable(self, "_on_sell_selected"))
	sell_vbox.add_child(sell_list)
	player_gold_label = _lbl("", 13)
	player_gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.2))
	sell_vbox.add_child(player_gold_label)
	sell_btn = _btn("Sell", 100)
	sell_btn.disabled = true
	sell_btn.connect("pressed", Callable(self, "_on_sell_pressed"))
	sell_vbox.add_child(sell_btn)

	close_btn = _btn("Close (E)", 120)
	close_btn.connect("pressed", Callable(self, "close"))
	sell_vbox.add_child(close_btn)


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
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	player_gold_label.text = "Your Gold: %d GP" % ResourceStash.gold
	shop_gold_label.text = ""
	buy_list.clear()
	for i in range(merchant_inventory.size()):
		var item: Dictionary = merchant_inventory[i]
		var txt: String = item.get("name", "?")
		var gp: int = item.get("gp", 0)
		txt += "  â€”  %d GP" % gp
		if item.get("is_weapon", false):
			txt = "Weapon: " + txt
			var db: int = item.get("damage_bonus", 0)
			if db > 0: txt += "  (+%d dmg)" % db
		buy_list.add_item(txt)
	buy_btn.disabled = true

	sell_list.clear()
	for i in range(ResourceStash.inventory.size()):
		var item: Dictionary = ResourceStash.inventory[i]
		var txt: String = item.get("name", "?")
		var gp: int = item.get("gp", 0)
		if gp > 0:
			txt += "  â€”  %d GP" % int(gp * 0.5)
		sell_list.add_item(txt)
	sell_btn.disabled = true


func _on_buy_selected(index: int) -> void:
	buy_btn.disabled = false
	shop_gold_label.text = "Price: %d GP" % merchant_inventory[index].get("gp", 0)


func _on_sell_selected(index: int) -> void:
	sell_btn.disabled = false


func _on_buy_pressed() -> void:
	var selected := buy_list.get_selected_items()
	if selected.is_empty():
		return
	var item: Dictionary = merchant_inventory[selected[0]]
	var price: int = item.get("gp", 0)
	if not ResourceStash.spend_gold(price):
		return
	ResourceStash.add_item(item)
	merchant_inventory.remove_at(selected[0])
	_refresh()


func _on_sell_pressed() -> void:
	var selected := sell_list.get_selected_items()
	if selected.is_empty():
		return
	var item: Dictionary = ResourceStash.inventory[selected[0]]
	var price: int = item.get("gp", 0)
	if price > 0:
		ResourceStash.add_gold(int(price * 0.5))
	ResourceStash.remove_item(selected[0])
	_refresh()


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


func _is_combat_active() -> bool:
	var cm: Node = get_parent().get_node_or_null("CombatManager") if get_parent() else null
	return cm != null and cm.has_method("is_active") and cm.is_active()
