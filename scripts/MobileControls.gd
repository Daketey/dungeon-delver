extends CanvasLayer
## Touch controls for Android/mobile. Virtual joystick on left half,
## camera drag on right half, action buttons bottom-right.

# Action signals — World connects to these
signal interact_pressed
signal inventory_pressed
signal map_pressed

@onready var _joystick_base: ColorRect = $JoystickBase
@onready var _joystick_thumb: ColorRect = $JoystickBase/Thumb
@onready var _interact_btn: Button = $InteractBtn
@onready var _inv_btn: Button = $InventoryBtn
@onready var _map_btn: Button = $MapBtn

var _joy_touch_idx: int = -1
var _joy_center: Vector2 = Vector2.ZERO
var _joy_radius: float = 90.0
var _look_touch_idx: int = -1
var _look_prev: Vector2 = Vector2.ZERO

var _move_dir: Vector2 = Vector2.ZERO
var _look_delta: float = 0.0

const DEAD_ZONE: float = 15.0
const LOOK_SENS: float = 0.15


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	visible = true

	var vs := get_viewport().get_visible_rect().size

	_joy_center = Vector2(130, vs.y - 180)
	_joystick_base.size = Vector2(_joy_radius * 2, _joy_radius * 2)
	_joystick_base.position = _joy_center - Vector2(_joy_radius, _joy_radius)
	_joystick_thumb.position = Vector2(_joy_radius - 30, _joy_radius - 30)
	_joystick_thumb.size = Vector2(60, 60)

	_interact_btn.position = Vector2(vs.x - 180, vs.y - 130)
	_interact_btn.size = Vector2(140, 70)
	_inv_btn.position = Vector2(vs.x - 100, 40)
	_inv_btn.size = Vector2(70, 50)
	_map_btn.position = Vector2(vs.x - 180, 40)
	_map_btn.size = Vector2(70, 50)

	_interact_btn.pressed.connect(func(): emit_signal("interact_pressed"))
	_inv_btn.pressed.connect(func(): emit_signal("inventory_pressed"))
	_map_btn.pressed.connect(func(): emit_signal("map_pressed"))


func _process(_delta: float) -> void:
	# Push current input state to the player each frame
	var player := _find_player()
	if player:
		player.mobile_move_dir = _move_dir
		player.mobile_look_delta = _look_delta
		_look_delta = 0.0  # consume after one frame


func _find_player() -> GridPlayer:
	var root := get_tree().get_root()
	if root:
		var p := root.get_node_or_null("World3/Player")
		if p and p is GridPlayer:
			return p as GridPlayer
	return null


func _input(event: InputEvent) -> void:
	if not event is InputEventScreenTouch and not event is InputEventScreenDrag:
		return

	var idx: int = event.index
	var pos: Vector2 = event.position
	var vs := get_viewport().get_visible_rect().size

	if event is InputEventScreenTouch:
		if event.pressed:
			if pos.x < vs.x * 0.5 and _joy_touch_idx == -1:
				_joy_touch_idx = idx
				_joy_center = pos
				_joystick_base.position = pos - Vector2(_joy_radius, _joy_radius)
				_joystick_thumb.position = Vector2(_joy_radius - 30, _joy_radius - 30)
				_joystick_base.visible = true
			elif pos.x >= vs.x * 0.5 and _look_touch_idx == -1:
				_look_touch_idx = idx
				_look_prev = pos
		else:
			if idx == _joy_touch_idx:
				_joy_touch_idx = -1
				_move_dir = Vector2.ZERO
				_joystick_thumb.position = Vector2(_joy_radius - 30, _joy_radius - 30)
				_joystick_base.visible = false
			elif idx == _look_touch_idx:
				_look_touch_idx = -1

	elif event is InputEventScreenDrag:
		if idx == _joy_touch_idx:
			var offset: Vector2 = pos - _joy_center
			if offset.length() > _joy_radius:
				offset = offset.normalized() * _joy_radius
			_joystick_thumb.position = Vector2(_joy_radius - 30, _joy_radius - 30) + offset

			if offset.length() < DEAD_ZONE:
				_move_dir = Vector2.ZERO
			else:
				_move_dir = (offset / _joy_radius).limit_length(1.0)
				_move_dir.y = -_move_dir.y

		elif idx == _look_touch_idx:
			_look_delta = (pos.x - _look_prev.x) * LOOK_SENS
			_look_prev = pos
