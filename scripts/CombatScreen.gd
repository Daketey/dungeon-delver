extends CanvasLayer
class_name CombatScreen

var combat_manager: CombatManager = null
var _feat_first: int = -1
var _flash_tween: Tween = null
var _pre_combat_pos: Vector3 = Vector3.ZERO
var _pre_combat_rot: Vector3 = Vector3.ZERO
var _pre_enemy_pos: Vector3 = Vector3.ZERO
var _combat_enemy: CharacterBody3D = null
var _end_timer: SceneTreeTimer = null
var _feat_overlay: Control = null
var _feat_clicked: int = -1

const COMBAT_DISTANCE: float = 2.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 50
	visible = false
	_connect_signals()


func _connect_signals() -> void:
	for btn_info: Array in [
		[$BottomPanel/BtnRow/AtkBtn, _on_atk],
		[$BottomPanel/BtnRow/FeatBtn, _on_feat],
		[$BottomPanel/BtnRow/ItemBtn, _on_item],
		[$BottomPanel/BtnRow/FleeBtn, _on_flee],
		[$BottomPanel/ResolveBtn, _on_resolve],
	]:
		var btn: Button = btn_info[0] as Button
		var cb: Callable = btn_info[1] as Callable
		if btn.pressed.is_connected(cb):
			btn.pressed.disconnect(cb)
		btn.pressed.connect(cb)


func _reposition_flash() -> void:
	$Flash.size = get_viewport().get_visible_rect().size


func _cm() -> CombatManager:
	if combat_manager: return combat_manager
	combat_manager = get_parent().get_node_or_null("CombatManager") as CombatManager
	return combat_manager


func start_combat(player: CharacterBody3D, enemy: CharacterBody3D) -> void:
	combat_manager = get_parent().get_node_or_null("CombatManager") as CombatManager
	if combat_manager == null: return
	_connect_signals()

	_pre_combat_pos = player.global_position
	_pre_combat_rot = player.rotation
	_pre_enemy_pos = enemy.global_position
	_combat_enemy = enemy

	var player_pos: Vector3 = player.global_position
	var forward: Vector3 = -player.basis.z
	forward.y = 0.0
	if forward.length() < 0.1:
		forward = Vector3(0, 0, -1)
	forward = forward.normalized()
	var enemy_pos: Vector3 = player_pos + forward * COMBAT_DISTANCE
	enemy_pos.x = round(enemy_pos.x / Globals.GRID_SIZE) * Globals.GRID_SIZE
	enemy_pos.z = round(enemy_pos.z / Globals.GRID_SIZE) * Globals.GRID_SIZE
	enemy.global_position = enemy_pos

	player.look_at(enemy_pos, Vector3.UP)
	enemy.look_at(player_pos, Vector3.UP)

	_reposition_flash()
	visible = true
	var p: GridPlayer = player as GridPlayer
	if p: p.combat_active = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	$BottomPanel/EnemyNameLbl.text = enemy.enemy_name if "enemy_name" in enemy else "Monster"
	$BottomPanel/DiceLbl.text = ""
	_hide_dice()
	$BottomPanel/ResolveBtn.disabled = true
	_refresh(player, enemy)
	_update_btns()
	$BottomPanel/BtnRow/AtkBtn.disabled = false
	$BottomPanel/BtnRow/FleeBtn.disabled = false
	$BottomPanel/BtnRow/AtkBtn.grab_focus()


func _refresh(_player: CharacterBody3D, enemy: CharacterBody3D) -> void:
	var ef: float = clamp(float(enemy.health) / float(enemy.max_health), 0.0, 1.0)
	$BottomPanel/EnemyHpBar.size.x = min(get_viewport().get_visible_rect().size.x - 40, 500) * ef
	$BottomPanel/EnemyHpBar.color = Color(0.8, 0.2, 0.2) if ef > 0.5 else (Color.ORANGE if ef > 0.25 else Color.RED)
	$BottomPanel/EnemyHpText.text = "%s  HP: %d / %d" % [enemy.enemy_name if "enemy_name" in enemy else "Enemy", enemy.health, enemy.max_health]


func update_status(_msg: String) -> void: pass

func on_combat_update(player: CharacterBody3D, enemy: CharacterBody3D) -> void:
	_refresh(player, enemy); _update_btns()


func end_combat(_p: CharacterBody3D, _e: CharacterBody3D, victory: bool) -> void:
	_popup_result(victory)
	_feat_first = -1
	if _end_timer:
		_end_timer.timeout.disconnect(_on_end_timer)
	_end_timer = get_tree().create_timer(1.5)
	_end_timer.timeout.connect(_on_end_timer)


func _popup_result(victory: bool) -> void:
	var vs := get_viewport().get_visible_rect().size
	var lbl := Label.new()
	lbl.text = "VICTORY!" if victory else "DEFEAT..."
	lbl.add_theme_font_size_override("font_size", 56)
	lbl.add_theme_color_override("font_color", Color.GOLD if victory else Color.RED)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(0, vs.y * 0.35)
	lbl.size = Vector2(vs.x, 80)
	add_child(lbl)
	var tween := create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 1.2).set_delay(0.8)
	tween.tween_callback(lbl.queue_free)


func _on_end_timer() -> void:
	var cm: CombatManager = _cm()
	if cm and cm.is_active():
		return
	visible = false
	var inv: Node = get_parent().get_node_or_null("InventoryScreen")
	var shop: Node = get_parent().get_node_or_null("ShopScreen")
	if (not inv or not inv.visible) and (not shop or not shop.visible) and not get_tree().paused:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var p: GridPlayer = get_parent().get_node_or_null("Player") as GridPlayer
	if p:
		p.combat_active = false
		p.rotation = _pre_combat_rot
	_combat_enemy = null


func _show_dice(hit: int, dmg: int, dfn: int) -> void:
	var roller_scr: GDScript = load("res://scripts/DiceRoller.gd") as GDScript
	var roller: Control = roller_scr.new()
	roller.name = "DiceRoller"
	add_child(roller)
	var specs: Array = [
		{sides=8, result=hit, label="HIT"},
		{sides=6, result=dmg, label="DMG"},
		{sides=4, result=dfn, label="DEF"},
	]
	if roller.has_method("roll"):
		roller.roll(specs)

	_hide_dice()
	_feat_first = -1
	var feats_ok: bool = _cm() != null and _cm().feats_remaining() > 0
	$BottomPanel/BtnRow/AtkBtn.disabled = true
	$BottomPanel/BtnRow/FleeBtn.disabled = false
	$BottomPanel/BtnRow/ItemBtn.disabled = true
	$BottomPanel/BtnRow/FeatBtn.disabled = not feats_ok
	$BottomPanel/ResolveBtn.disabled = false
	$BottomPanel/ResolveBtn.visible = true
	$BottomPanel/ResolveBtn.grab_focus()


func _update_btns() -> void:
	var cm: CombatManager = _cm()
	var active: bool = cm != null and cm.is_active()
	var fresh: bool = active and cm.dice_are_fresh
	$BottomPanel/BtnRow/AtkBtn.disabled = not active or fresh
	$BottomPanel/BtnRow/FeatBtn.disabled = not fresh or (cm.feats_remaining() <= 0 if cm else true)
	$BottomPanel/BtnRow/ItemBtn.disabled = not active or fresh
	$BottomPanel/BtnRow/FleeBtn.disabled = not active
	$BottomPanel/ResolveBtn.disabled = not fresh
	if not fresh and active: $BottomPanel/BtnRow/AtkBtn.grab_focus()


func _on_atk() -> void:
	var cm: CombatManager = _cm()
	if cm == null or not cm.is_active() or cm.dice_are_fresh: return
	_disable_all(); cm.roll_dice()

func _on_feat() -> void:
	var cm: CombatManager = _cm()
	if cm == null or not cm.dice_are_fresh: return
	_disable_all(); _build_feat_btns()

func _on_item() -> void:
	var inv: Node = get_parent().get_node_or_null("InventoryScreen")
	if inv and inv.has_method("open"): inv.open()

func _on_flee() -> void:
	var cm: CombatManager = _cm()
	if cm == null: return
	_disable_all(); cm.flee()

func _on_resolve() -> void:
	var cm: CombatManager = _cm()
	if cm == null or not cm.dice_are_fresh: return
	_disable_all(); $BottomPanel/ResolveBtn.disabled = true; cm.resolve_turn()

func _disable_all() -> void:
	$BottomPanel/BtnRow/AtkBtn.disabled = true; $BottomPanel/BtnRow/FeatBtn.disabled = true
	$BottomPanel/BtnRow/ItemBtn.disabled = true; $BottomPanel/BtnRow/FleeBtn.disabled = true
	$BottomPanel/ResolveBtn.disabled = true


func _build_feat_btns() -> void:
	_hide_dice()
	var cm: CombatManager = _cm()
	if cm == null: return
	_feat_clicked = -1

	var vs := get_viewport().get_visible_rect().size
	var overlay := Panel.new()
	overlay.name = "FeatOverlay"
	overlay.size = Vector2(340, 160)
	overlay.position = (vs - overlay.size) / 2.0
	overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(overlay)
	_feat_overlay = overlay

	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.15, 0.95)
	bg.size = overlay.size
	overlay.add_child(bg)

	var title := Label.new()
	title.text = "Pick two dice to swap (Heroic Feat)"
	title.add_theme_font_size_override("font_size", 16)
	title.add_theme_color_override("font_color", Color.WHITE)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position = Vector2(10, 10)
	title.size = Vector2(320, 24)
	overlay.add_child(title)

	var dice_textures := {
		8: preload("res://Dice/d8.png"),
		6: preload("res://Dice/d6.png"),
		4: preload("res://Dice/d4.png"),
	}
	var vals: Array = [cm.last_hit_roll, cm.last_damage_roll, cm.last_defense_roll]
	var labels: Array = ["HIT d8", "DMG d6", "DEF d4"]
	var sides: Array = [8, 6, 4]
	for i in range(3):
		var x_pos: float = 20 + i * 108
		var btn := Button.new()
		btn.name = "feat_die_%d" % i
		btn.size = Vector2(96, 90)
		btn.position = Vector2(x_pos, 50)
		var idx: int = i
		btn.pressed.connect(func(): _on_feat_click(idx))
		overlay.add_child(btn)

		var img := TextureRect.new()
		img.texture = dice_textures.get(sides[i])
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		img.size = Vector2(48, 48)
		img.position = Vector2(24, 4)
		btn.add_child(img)

		var lbl := Label.new()
		lbl.text = "%s: %d" % [labels[i], vals[i]]
		lbl.add_theme_font_size_override("font_size", 11)
		lbl.add_theme_color_override("font_color", Color.WHITE)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.position = Vector2(0, 56)
		lbl.size = Vector2(96, 30)
		btn.add_child(lbl)

	var cancel_btn := Button.new()
	cancel_btn.text = "Cancel"
	cancel_btn.size = Vector2(80, 28)
	cancel_btn.position = Vector2(130, 145)
	cancel_btn.pressed.connect(_hide_feat_overlay)
	overlay.add_child(cancel_btn)

	$BottomPanel/DiceLbl.text = "Pick two dice to swap..."


func _hide_feat_overlay() -> void:
	if _feat_overlay:
		_feat_overlay.queue_free()
		_feat_overlay = null
	_feat_clicked = -1
	_update_btns()
	$BottomPanel/BtnRow/AtkBtn.grab_focus()

func _hide_dice() -> void:
	_hide_feat_overlay()
	for c in $BottomPanel/DiceRow.get_children(): c.queue_free()

func _on_feat_click(idx: int) -> void:
	var cm: CombatManager = _cm()
	if cm == null: return
	if _feat_clicked < 0:
		_feat_clicked = idx
		var btn := _feat_overlay.get_node_or_null("feat_die_%d" % idx) as Button
		if btn: btn.modulate = Color(1.0, 0.8, 0.3)
		$BottomPanel/DiceLbl.text = "Swap %s with...?" % ["d8", "d6", "d4"][idx]
	else:
		cm.swap_dice(_feat_clicked, idx)
		_hide_feat_overlay()
		_hide_dice()
		_feat_clicked = -1


func flash_red() -> void: _do_flash(Color(1.0, 0.0, 0.0, 0.4))
func flash_white() -> void: _do_flash(Color(1.0, 1.0, 1.0, 0.3))

func _do_flash(c: Color) -> void:
	if _flash_tween and _flash_tween.is_running(): _flash_tween.kill()
	$Flash.color = c
	_flash_tween = create_tween()
	_flash_tween.tween_property($Flash, "color", Color(0, 0, 0, 0), 0.35)


func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_accept") and not $BottomPanel/BtnRow/AtkBtn.disabled:
		_on_atk()
