extends CanvasLayer
## Riddle puzzle overlay. Player picks one of three answers.
## Correct → gold + treasure. Wrong → d4 damage + enemy spawns.

signal puzzle_result(correct: bool)

@onready var _panel: Panel = $Panel
@onready var _bg: ColorRect = $Panel/Background
@onready var _accent: ColorRect = $Panel/AccentBar
@onready var _title: Label = $Panel/TitleLabel
@onready var _riddle: Label = $Panel/RiddleLabel
@onready var _btn_a: Button = $Panel/OptionA
@onready var _btn_b: Button = $Panel/OptionB
@onready var _btn_c: Button = $Panel/OptionC
@onready var _result: Label = $Panel/ResultLabel
@onready var _close: Button = $Panel/CloseBtn

var _correct_index: int = -1
var _answered: bool = false
var _was_correct: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	visible = false


## Open with a riddle dict: {question, options: [A, B, C], correct: 0-2}
func open(riddle: Dictionary) -> void:
	_answered = false
	visible = true
	_correct_index = riddle.get("correct", 0)

	var vs := get_viewport().get_visible_rect().size
	var w: float = 500
	var h: float = 340
	_panel.size = Vector2(w, h)
	_panel.position = (vs - _panel.size) * 0.5

	_bg.size = _panel.size
	_accent.size = Vector2(w, 3)
	_accent.position = Vector2(0, 0)

	_title.position = Vector2(0, 12)
	_title.size = Vector2(w, 30)

	_riddle.text = riddle.get("question", "???")
	_riddle.position = Vector2(24, 52)
	_riddle.size = Vector2(w - 48, 80)

	var options: Array = riddle.get("options", ["?", "?", "?"])
	var btns: Array[Button] = [_btn_a, _btn_b, _btn_c]
	for i in range(3):
		var btn: Button = btns[i]
		btn.text = "  %s" % options[i]
		btn.position = Vector2(24, 144 + i * 48)
		btn.size = Vector2(w - 48, 38)
		btn.disabled = false
		btn.add_theme_color_override("font_color", Color.WHITE)
		# Reset button style
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.12, 0.22)
		sb.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("normal", sb)
		var sb_h := StyleBoxFlat.new()
		sb_h.bg_color = Color(0.22, 0.22, 0.35)
		sb_h.set_corner_radius_all(6)
		btn.add_theme_stylebox_override("hover", sb_h)

	_result.text = ""
	_result.position = Vector2(0, h - 58)
	_result.size = Vector2(w, 24)

	_close.position = Vector2((w - 120) * 0.5, h - 50)
	_close.visible = false

	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_btn_a.grab_focus()


func _on_option(index: int) -> void:
	if _answered:
		return
	_answered = true

	_was_correct = (index == _correct_index)
	AudioManager.play("ui_click")

	# Disable all choice buttons
	for btn in [_btn_a, _btn_b, _btn_c]:
		btn.disabled = true

	# Highlight correct answer in green, wrong in red
	var btns: Array[Button] = [_btn_a, _btn_b, _btn_c]
	for i in range(3):
		var sb := StyleBoxFlat.new()
		if i == _correct_index:
			sb.bg_color = Color(0.1, 0.4, 0.1)
		elif i == index and not _was_correct:
			sb.bg_color = Color(0.4, 0.1, 0.1)
		else:
			sb.bg_color = Color(0.08, 0.08, 0.15)
		sb.set_corner_radius_all(6)
		btns[i].add_theme_stylebox_override("normal", sb)

	if _was_correct:
		_result.text = "CORRECT — The puzzle unlocks!"
		_result.add_theme_color_override("font_color", Color(0.2, 0.9, 0.3))
	else:
		_result.text = "WRONG — Dark energy surges!"
		_result.add_theme_color_override("font_color", Color(0.9, 0.2, 0.2))

	_close.visible = true
	_close.grab_focus()


func _on_close() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("puzzle_result", _was_correct)
	queue_free()
