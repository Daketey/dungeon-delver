extends CanvasLayer
## Merchant buy/sell screen. Opened by interacting with the merchant (E key).

@onready var panel: Panel = $Panel
@onready var player_gold_label: Label = $Panel/MainHBox/SellVBox/PlayerGoldLabel
@onready var shop_gold_label: Label = $Panel/MainHBox/BuyVBox/ShopGoldLabel
@onready var buy_list: ItemList = $Panel/MainHBox/BuyVBox/BuyList
@onready var sell_list: ItemList = $Panel/MainHBox/SellVBox/SellList
@onready var buy_btn: Button = $Panel/MainHBox/BuyVBox/BuyBtn
@onready var sell_btn: Button = $Panel/MainHBox/SellVBox/SellBtn
@onready var close_btn: Button = $Panel/MainHBox/SellVBox/CloseBtn

var merchant_inventory: Array[Dictionary] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 110
	visible = false
	_panel_center()

	# Size the background and layout to match the panel
	#var bg: ColorRect = $Panel/Background
	#bg.size = panel.size
	#var hbox: HBoxContainer = $Panel/MainHBox
	#hbox.position = Vector2(12, 12)
	#hbox.size = panel.size - Vector2(40, 40)

	_generate_shop_inventory()


func _panel_center() -> void:
	#panel.size = Vector2(640, 480)
	var vp: Rect2 = get_viewport().get_visible_rect()
	panel.position = (vp.size - panel.size) * 0.5


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


func open() -> void:
	AudioManager.play("merchant_greet")
	_panel_center()
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
		txt += "  —  %d GP" % gp
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
			txt += "  —  %d GP" % int(gp * 0.5)
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
	AudioManager.play("shop_transaction")
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


func _is_combat_active() -> bool:
	var cm: Node = get_parent().get_node_or_null("CombatManager") if get_parent() else null
	return cm != null and cm.has_method("is_active") and cm.is_active()
