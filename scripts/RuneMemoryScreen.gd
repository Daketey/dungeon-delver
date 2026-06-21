extends CanvasLayer
class_name RuneMemoryScreen
## Rune memory puzzle — watch the sequence, click runes in order.

signal puzzle_result(correct: bool)

const LIT_MODULATE: Array[Color] = [
	Color(2.0, 0.7, 0.7),   # bright red
	Color(0.7, 0.9, 2.0),   # bright blue
	Color(0.7, 2.0, 0.8),   # bright green
	Color(2.0, 1.7, 0.7),   # bright gold
]
const DIM_MODULATE: Color = Color(0.4, 0.4, 0.5)

@onready var _panel: Panel = $Panel
@onready var _bg: ColorRect = $Panel/Background
@onready var _accent: ColorRect = $Panel/AccentBar
@onready var _title: Label = $Panel/TitleLabel
@onready var _hint: Label = $Panel/HintLabel
@onready var _runes_hbox: HBoxContainer = $Panel/RunesHBox
@onready var _result: Label = $Panel/ResultLabel
@onready var _close: Button = $Panel/CloseBtn
@onready var _runes: Array[Button] = [$Panel/RunesHBox/Rune0, $Panel/RunesHBox/Rune1, $Panel/RunesHBox/Rune2, $Panel/RunesHBox/Rune3]

var _sequence: Array[int] = []
var _click_index: int = 0
var _active: bool = false
var _was_correct: bool = false
var _flash_timer: Timer = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	visible = false

	for btn in _runes:
		btn.modulate = DIM_MODULATE
		btn.disabled = true


func open() -> void:
	_sequence.clear()
	_click_index = 0
	_active = false
	_was_correct = false
	visible = true

	var length: int = 3 + randi() % 2
	for _i in range(length):
		_sequence.append(randi() % 4)

	var vs := get_viewport().get_visible_rect().size
	const W: float = 380
	const H: float = 260
	_panel.size = Vector2(W, H)
	_panel.position = (vs - _panel.size) * 0.5

	_bg.size = _panel.size
	_accent.size = Vector2(W, 3)

	_title.position = Vector2(0, 12)
	_title.size = Vector2(W, 30)

	_hint.text = "Watch the sequence..."
	_hint.position = Vector2(0, 52)
	_hint.size = Vector2(W, 24)

	var total_w: float = 4 * 64 + 3 * 16
	_runes_hbox.position = Vector2((W - total_w) * 0.5, 90)

	for btn in _runes:
		btn.modulate = DIM_MODULATE
		btn.disabled = true

	_result.text = ""
	_result.position = Vector2(0, 175)
	_result.size = Vector2(W, 24)

	_close.visible = false
	_close.position = Vector2((W - 110) * 0.5, H - 50)

	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	# Flash the sequence using a Timer node
	_flash_timer = Timer.new()
	_flash_timer.one_shot = false
	_flash_timer.wait_time = 0.8  # initial delay before first flash
	add_child(_flash_timer)
	_flash_timer.timeout.connect(_on_flash_tick)
	_flash_timer.start()

	_flash_step = 0
	_flash_lit = false


var _flash_step: int = 0
var _flash_lit: bool = false

func _on_flash_tick() -> void:
	if _flash_step < _sequence.size() * 2:
		var seq_idx: int = _flash_step / 2
		var is_lit: bool = (_flash_step % 2 == 0)

		if is_lit:
			_runes[_sequence[seq_idx]].modulate = LIT_MODULATE[_sequence[seq_idx]]
			_flash_timer.wait_time = 0.45
		else:
			_runes[_sequence[seq_idx]].modulate = DIM_MODULATE
			_flash_timer.wait_time = 0.2

		_flash_step += 1
		_flash_timer.start()
	else:
		# Sequence done — player's turn
		_flash_timer.queue_free()
		_flash_timer = null
		_hint.text = "Your turn! Click in order."
		_active = true
		for btn in _runes:
			btn.disabled = false
		get_tree().paused = true


func _on_rune_pressed(index: int) -> void:
	if not _active:
		return

	if index != _sequence[_click_index]:
		_active = false
		_was_correct = false
		for btn in _runes:
			btn.disabled = true
		_hint.text = ""
		_result.text = "WRONG — The altar rejects you!"
		_result.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))
		_close.visible = true
		_close.grab_focus()
		return

	AudioManager.play("ui_click")
	_click_index += 1
	if _click_index >= _sequence.size():
		_active = false
		_was_correct = true
		for btn in _runes:
			btn.disabled = true
		_hint.text = ""
		_result.text = "CORRECT — The altar unlocks!"
		_result.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
		_close.visible = true
		_close.grab_focus()


func _on_close() -> void:
	if _flash_timer:
		_flash_timer.queue_free()
		_flash_timer = null
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("puzzle_result", _was_correct)
	queue_free()
