extends CharacterBody3D
class_name GridPlayer

signal moved(tile: Vector2i)

@export var level: int = 1
@export var max_health: int = 15
@export var damage_mod: int = 0
@export var defense_mod: int = 0
var health: int = 0
var heroic_feats: Array = [true]

var grid_pos: Vector2i = Vector2i.ZERO
var combat_active: bool = false
var movement_locked_until: float = 0.0

# Mobile input — set by MobileControls overlay each frame
var mobile_move_dir: Vector2 = Vector2.ZERO
var mobile_look_delta: float = 0.0
var is_mobile: bool = false

@onready var neck := $Neck
@onready var camera := $Neck/Camera3D
@onready var torch := $Neck/SpotLight3D

const MOVE_SPEED: float = 5.0
const MOUSE_SENS: float = 0.002


func _ready() -> void:
	health = max_health
	grid_pos = Vector2i(int(round(position.x / Globals.GRID_SIZE)), int(round(position.z / Globals.GRID_SIZE)))
	if not is_mobile:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)


func _physics_process(delta: float) -> void:
	if combat_active:
		return
	if Time.get_ticks_msec() * 0.001 < movement_locked_until:
		return

	if is_mobile:
		# Touch camera look
		if abs(mobile_look_delta) > 0.01:
			rotation_degrees.y -= mobile_look_delta

		# Virtual joystick movement
		var wish_dir := Vector3(mobile_move_dir.x, 0, mobile_move_dir.y)
		wish_dir = wish_dir.rotated(Vector3.UP, rotation.y)

		if wish_dir.length() > 0.1:
			velocity = wish_dir * MOVE_SPEED
		else:
			velocity = Vector3.ZERO

		# Reset deltas after consuming
		mobile_look_delta = 0.0
	else:
		# Mouse look (horizontal only — camera neck handles vertical)
		var mouse_delta := Input.get_last_mouse_velocity()
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			rotation_degrees.y -= mouse_delta.x * MOUSE_SENS

		# WASD movement
		var input_dir := Input.get_vector("strafe_left", "strafe_right", "forward", "back")
		var wish_dir := Vector3(input_dir.x, 0, input_dir.y).normalized()
		wish_dir = wish_dir.rotated(Vector3.UP, rotation.y)

		if wish_dir.length() > 0.1:
			velocity = wish_dir * MOVE_SPEED
		else:
			velocity = Vector3.ZERO

	move_and_slide()

	# Update logical grid position from actual position
	grid_pos = Vector2i(int(round(position.x / Globals.GRID_SIZE)), int(round(position.z / Globals.GRID_SIZE)))


func _unhandled_input(event: InputEvent) -> void:
	if is_mobile or combat_active:
		return
	if event is InputEventMouseButton:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	elif event.is_action_pressed("ui_cancel"):
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)


func set_grid_position(tile: Vector2i) -> void:
	grid_pos = tile
	position = Vector3(tile.x * Globals.GRID_SIZE, 0, tile.y * Globals.GRID_SIZE)


func lock_camera_to(target: Node3D) -> void:
	var look_target := target.global_position + Vector3(0, 1.25, 0)
	var tween := create_tween()
	tween.tween_method(_look_at_target.bind(look_target), 0.0, 1.0, 0.4)

func _look_at_target(_t: float, target_pos: Vector3) -> void:
	neck.look_at(target_pos, Vector3.UP)

func unlock_camera() -> void:
	var tween := create_tween()
	tween.tween_property(neck, "rotation", Vector3.ZERO, 0.3)
