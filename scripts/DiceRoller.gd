extends Control
## Animated dice roller — shows dice images with rolling animation in top-right.

const DICE_TEXTURES: Dictionary = {
	4:  preload("res://Dice/d4.png"),
	6:  preload("res://Dice/d6.png"),
	8:  preload("res://Dice/d8.png"),
	10: preload("res://Dice/d10.png"),
	12: preload("res://Dice/d12.png"),
	20: preload("res://Dice/d20.png"),
}

const TOTAL_FRAMES: int = 8
const FRAME_DELAY: float = 0.08


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


## Show rolling dice animation. dice_specs = [{sides, result, label}, ...]
func roll(dice_specs: Array) -> void:
	# Clear previous
	for c in get_children():
		c.queue_free()

	var vs := get_viewport().get_visible_rect().size
	position = Vector2(vs.x - 200, 40)
	size = Vector2(185, 135)

	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.7)
	bg.size = size
	add_child(bg)

	for i in range(dice_specs.size()):
		var spec: Dictionary = dice_specs[i]
		var sides: int = spec.get("sides", 6)
		var result: int = spec.get("result", 1)
		var label: String = spec.get("label", "")

		var y_pos: float = 8.0 + i * 42.0

		# Die image
		var tex: Texture2D = DICE_TEXTURES.get(sides)
		if tex:
			var img := TextureRect.new()
			img.texture = tex
			img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			img.size = Vector2(36, 36)
			img.position = Vector2(8, y_pos)
			add_child(img)

		# Result number
		var val_lbl := Label.new()
		val_lbl.text = str(result)
		val_lbl.add_theme_font_size_override("font_size", 22)
		val_lbl.add_theme_color_override("font_color", Color.WHITE)
		val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		val_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		val_lbl.size = Vector2(40, 36)
		val_lbl.position = Vector2(50, y_pos)
		add_child(val_lbl)

		# Label
		var name_lbl := Label.new()
		name_lbl.text = "%s (d%d)" % [label, sides]
		name_lbl.add_theme_font_size_override("font_size", 13)
		name_lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.size = Vector2(120, 36)
		name_lbl.position = Vector2(95, y_pos)
		add_child(name_lbl)

		# Flash the value label
		var tween := create_tween()
		tween.tween_method(_flash_val.bind(val_lbl, result, sides), 0.0, 1.0, FRAME_DELAY * TOTAL_FRAMES)

	# Auto-remove
	var fade := create_tween()
	fade.tween_interval(3.0)
	fade.tween_property(bg, "modulate:a", 0.0, 0.5)
	fade.tween_callback(queue_free)


func _flash_val(t: float, lbl: Label, final_val: int, sides: int) -> void:
	var frame: int = int(t * TOTAL_FRAMES)
	if frame >= TOTAL_FRAMES - 1:
		lbl.text = str(final_val)
		lbl.add_theme_color_override("font_color", Color.WHITE)
	else:
		lbl.text = str(randi() % sides + 1)
		lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
