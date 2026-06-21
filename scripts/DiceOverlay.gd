extends CanvasLayer
## Reusable dice overlay — traps and treasures both use this to let the
## player roll their own fate instead of an invisible background roll.

signal roll_result(value: int)

const DICE_TEXTURES: Dictionary = {
	4: preload("res://Dice/d4.png"),
	6: preload("res://Dice/d6.png"),
	8: preload("res://Dice/d8.png"),
}

@onready var _panel: Panel = $Panel
@onready var _title: Label = $Panel/TitleLabel
@onready var _context: Label = $Panel/ContextLabel
@onready var _dice_tex: TextureRect = $Panel/DiceTexture
@onready var _result: Label = $Panel/ResultLabel
@onready var _roll_btn: Button = $Panel/RollBtn
@onready var _close_btn: Button = $Panel/CloseBtn

var _sides: int = 6
var _rolled: bool = false
var _roll_value: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 120
	visible = false

## Open the overlay. sides = 6 or 8, context = what the roll is for.
func open(sides: int, context: String) -> void:
	_sides = sides
	_rolled = false
	_roll_value = 0
	visible = true

	const W: float = 280
	const H: float = 300

	var vs := get_viewport().get_visible_rect().size
	_panel.size = Vector2(W, H)
	_panel.position = (vs - _panel.size) * 0.5

	$Panel/Background.size = _panel.size
	$Panel/AccentBar.size = Vector2(W, 3)

	_title.position = Vector2(0, 14)
	_title.size = Vector2(W, 30)

	_context.text = context
	_context.position = Vector2(16, 50)
	_context.size = Vector2(W - 32, 44)

	var tex: Texture2D = DICE_TEXTURES.get(sides)
	if tex:
		_dice_tex.texture = tex
		_dice_tex.size = Vector2(96, 96)
		_dice_tex.position = Vector2((W - 96) * 0.5, 98)

	_result.text = ""
	_result.position = Vector2(0, 205)
	_result.size = Vector2(W, 32)
	_result.add_theme_color_override("font_color", Color.WHITE)

	_roll_btn.position = Vector2((W - 160) * 0.5, 248)
	_roll_btn.disabled = false
	_roll_btn.visible = true

	_close_btn.position = Vector2((W - 110) * 0.5, 250)
	_close_btn.visible = false

	get_tree().paused = true
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	_roll_btn.grab_focus()


func _on_roll_pressed() -> void:
	if _rolled:
		return
	_rolled = true
	_roll_value = randi() % _sides + 1
	_roll_btn.disabled = true
	AudioManager.play("dice_roll")

	# Quick flash animation of random faces
	_animate_roll()

	# Show result after a short delay, then auto-close
	await get_tree().create_timer(0.8).timeout
	_show_result()


func _animate_roll() -> void:
	var frames: int = 10
	for i in range(frames):
		var fake: int = randi() % _sides + 1
		_result.text = str(fake)
		_result.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
		await get_tree().create_timer(0.05).timeout


func _show_result() -> void:
	_result.text = "%d" % _roll_value
	_result.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
	_roll_btn.visible = false
	_close_btn.visible = true
	_close_btn.grab_focus()


func _on_close_pressed() -> void:
	visible = false
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	emit_signal("roll_result", _roll_value)
	queue_free()
