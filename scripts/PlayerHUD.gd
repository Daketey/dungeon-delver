extends CanvasLayer

var hp_label: Label
var gold_label: Label
var kill_label: Label
var hint_label: Label
var bg: ColorRect
var explored_label: Label

# Flash overlay
var _flash: ColorRect = null
var _flash_tween: Tween = null

# Notification log
var _log_scroll: ScrollContainer = null
var _log_vbox: VBoxContainer = null
var _log_history: Control = null
var _hist_vbox: VBoxContainer = null
var _log_labels: Array[Label] = []
const MAX_LOG: int = 80


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

	# Cache node references
	bg = $Bg
	hp_label = $StatsVBox/HpLabel
	gold_label = $StatsVBox/GoldLabel
	kill_label = $StatsVBox/KillLabel
	hint_label = $HintLabel
	explored_label = $ExploredLabel
	_flash = $Flash
	_log_scroll = $LogScroll
	_log_vbox = $LogScroll/LogVBox
	_log_history = $LogHistory
	_hist_vbox = $LogHistory/HistScroll/HistoryVBox


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode == KEY_L and event.pressed:
		if _log_history:
			_log_history.visible = not _log_history.visible
			if _log_history.visible:
				_refresh_history()
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _refresh_history() -> void:
	var hist_scroll := _hist_vbox
	if not hist_scroll: return
	for c in hist_scroll.get_children():
		c.queue_free()
	for lbl in _log_labels:
		if not is_instance_valid(lbl): continue
		var copy := Label.new()
		copy.text = lbl.text
		copy.add_theme_font_size_override("font_size", 13)
		copy.add_theme_color_override("font_color", lbl.get_theme_color("font_color"))
		copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hist_scroll.add_child(copy)


func _process(_delta: float) -> void:
	var player = _find_player()
	if player:
		var hp: int = player.health; var max_hp: int = player.max_health
		var hp_color: Color = Color.RED
		if hp > max_hp * 0.6: hp_color = Color.GREEN
		elif hp > max_hp * 0.3: hp_color = Color.ORANGE
		hp_label.text = "HP: %d / %d" % [hp, max_hp]
		hp_label.add_theme_color_override("font_color", hp_color)
	gold_label.text = "Gold: %d" % ResourceStash.gold
	kill_label.text = "Kills: %d / 10" % ResourceStash.kill_count
	if ResourceStash.boss_active:
		kill_label.text += "  BOSS READY"
		kill_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))


func flash_red() -> void:
	if _flash_tween and _flash_tween.is_running():
		_flash_tween.kill()
	_flash.color = Color(1, 0, 0, 0.45)
	_flash_tween = create_tween()
	_flash_tween.tween_property(_flash, "color", Color(1, 0, 0, 0), 0.4)


func show_hint(text: String) -> void:
	if hint_label: hint_label.text = text


var _active_notifications: Array = []

func show_notification(text: String, color: Color = Color.WHITE, duration: float = 2.5) -> void:
	_cleanup_notifications()

	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 24)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var vs := get_viewport().get_visible_rect().size
	var base_y: float = vs.y * 0.30
	var offset: float = _active_notifications.size() * 38.0
	lbl.position = Vector2(40, base_y + offset)
	lbl.size = Vector2(vs.x - 80, 34)
	add_child(lbl)
	_active_notifications.append(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, duration).set_trans(Tween.TRANS_QUAD).set_delay(duration * 0.3)
	tween.tween_callback(lbl.queue_free)

	_add_log_entry(text, color)


func _add_log_entry(text: String, color: Color) -> void:
	if not _log_vbox: return
	var entry := Label.new()
	entry.text = text
	entry.add_theme_font_size_override("font_size", 11)
	entry.add_theme_color_override("font_color", color)
	entry.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	entry.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_log_vbox.add_child(entry)
	_log_labels.append(entry)

	while _log_labels.size() > MAX_LOG:
		var old: Label = _log_labels.pop_front() as Label
		if is_instance_valid(old): old.queue_free()

	call_deferred("_scroll_log_to_bottom")


func _scroll_log_to_bottom() -> void:
	if _log_scroll:
		_log_scroll.scroll_vertical = _log_scroll.get_v_scroll_bar().max_value


func _cleanup_notifications() -> void:
	var valid: Array = []
	for n in _active_notifications:
		if is_instance_valid(n):
			valid.append(n)
	_active_notifications = valid


func show_pickup(text: String, color: Color) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var vs := get_viewport().get_visible_rect().size
	lbl.position = Vector2(vs.x / 2 - 100, vs.y * 0.55)
	lbl.size = Vector2(200, 30)
	add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "position:y", lbl.position.y - 50, 1.2).set_trans(Tween.TRANS_QUAD)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.2)
	tween.tween_callback(lbl.queue_free)


func set_explored(is_new: bool) -> void:
	if explored_label:
		if is_new:
			explored_label.text = "NEW AREA"
			explored_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
		else:
			explored_label.text = "EXPLORED"
			explored_label.add_theme_color_override("font_color", Color(0.3, 0.8, 0.3))


func _find_player() -> GridPlayer:
	var root := get_tree().get_root()
	if root:
		var p := root.get_node_or_null("World3/Player")
		if p and p is GridPlayer: return p as GridPlayer
	return null
