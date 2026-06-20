extends CanvasLayer
## Main menu shown on first launch. Play starts the game, Instructions shows rules.

signal play_pressed


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100
	visible = true
	_position_menu()
	_style_buttons()

	$MenuVBox/PlayBtn.pressed.connect(_on_play)
	$MenuVBox/InstrBtn.pressed.connect(_on_instructions)
	$MenuVBox/QuitBtn.pressed.connect(_on_quit)


func _position_menu() -> void:
	var vs := get_viewport().get_visible_rect().size
	$MenuVBox.position = Vector2(vs.x * 0.3, vs.y * 0.2)
	$MenuVBox.size = Vector2(vs.x * 0.4, vs.y * 0.6)


func _style_buttons() -> void:
	# Apply colored StyleBoxFlat backgrounds to buttons
	for btn_data in [
		[$MenuVBox/PlayBtn, Color(0.15, 0.4, 0.15)],
		[$MenuVBox/InstrBtn, Color(0.15, 0.15, 0.4)],
		[$MenuVBox/QuitBtn, Color(0.4, 0.1, 0.1)],
	]:
		var btn: Button = btn_data[0] as Button
		var col: Color = btn_data[1] as Color
		var sb := StyleBoxFlat.new()
		sb.bg_color = col
		sb.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", sb)
		btn.add_theme_stylebox_override("hover", sb)
		btn.add_theme_stylebox_override("pressed", sb)


func _on_play() -> void:
	queue_free()
	emit_signal("play_pressed")


func _on_instructions() -> void:
	_build_instructions_overlay()


func _build_instructions_overlay() -> void:
	var vs := get_viewport().get_visible_rect().size
	var overlay := Panel.new()
	overlay.name = "InstrOverlay"
	overlay.size = Vector2(520, 500)
	overlay.position = (vs - overlay.size) / 2.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)

	var bg2 := ColorRect.new()
	bg2.color = Color(0.08, 0.08, 0.14, 0.98)
	bg2.size = overlay.size
	overlay.add_child(bg2)

	var txt := Label.new()
	txt.text = "HOW TO PLAY\n\nYou are an adventurer entering a dungeon.\n\n" + \
		"MOVEMENT: WASD to walk, Mouse to look around.\n" + \
		"INTERACT: Press E near doors or the merchant.\n" + \
		"COMBAT: Approach enemies to fight. Roll dice:\n" + \
		"  · d8 HIT — beat enemy level to attack\n" + \
		"  · d6 DMG — your damage dealt\n" + \
		"  · d4 DEF — your damage blocked\n" + \
		"  · Natural 8 = re-roll damage. Natural 1 = swap.\n" + \
		"  · Heroic Feats: swap any two dice once per fight.\n" + \
		"  · Flee: take d4 damage and retreat.\n\n" + \
		"SHOP: Talk to the merchant (E key near him) to\n" + \
		"buy weapons and items with gold.\n\n" + \
		"BOSS: After 10 kills, the Greater Demon awaits.\n" + \
		"Find and defeat him to win!"
	txt.add_theme_font_size_override("font_size", 14)
	txt.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
	txt.position = Vector2(20, 15)
	txt.size = Vector2(480, 390)
	overlay.add_child(txt)

	var close_btn := Button.new()
	close_btn.text = "CLOSE"
	close_btn.custom_minimum_size = Vector2(120, 36)
	close_btn.position = Vector2(200, 450)
	close_btn.mouse_filter = Control.MOUSE_FILTER_STOP
	close_btn.pressed.connect(func(): overlay.queue_free())
	overlay.add_child(close_btn)


func _on_quit() -> void:
	get_tree().quit()
