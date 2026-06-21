extends Node3D
class_name PuzzlePedestal
## Marks a puzzle room. Pulses a glow orb; player presses E to activate the riddle.

signal player_activated

@onready var _orb: MeshInstance3D = $GlowOrb
@onready var _area: Area3D = $InteractionArea

var solved: bool = false
var _orb_mat: StandardMaterial3D = null
var _pulse_time: float = 0.0


func _ready() -> void:
	# Store a duplicate of the orb material so we can animate it independently
	if _orb and _orb.mesh:
		var src := _orb.get_surface_override_material(0)
		if src:
			_orb_mat = src.duplicate() as StandardMaterial3D
			_orb.set_surface_override_material(0, _orb_mat)

	_area.body_entered.connect(_on_body_entered)
	_area.body_exited.connect(_on_body_exited)


func _process(delta: float) -> void:
	if solved or _orb_mat == null:
		return
	_pulse_time += delta * 2.5
	var brightness: float = 1.0 + sin(_pulse_time) * 0.6
	_orb_mat.emission_energy_multiplier = brightness * 2.0


## Called when the puzzle is solved successfully.
func mark_solved() -> void:
	solved = true
	if _orb_mat:
		_orb_mat.albedo_color = Color(0.15, 0.7, 0.2)
		_orb_mat.emission = Color(0.1, 0.6, 0.05)
		_orb_mat.emission_energy_multiplier = 3.0


func _on_body_entered(body: Node3D) -> void:
	if solved:
		return
	if body is GridPlayer:
		_show_hint("Press E to examine the ancient pedestal")


func _on_body_exited(body: Node3D) -> void:
	if body is GridPlayer:
		_clear_hint()


func check_interact(player_pos: Vector3) -> bool:
	if solved:
		return false
	if player_pos.distance_to(global_position) < 2.5:
		_clear_hint()
		emit_signal("player_activated")
		return true
	return false


func _show_hint(text: String) -> void:
	var hud := get_node_or_null("/root/World3/PlayerHUD")
	if hud and hud.has_method("show_hint"):
		hud.show_hint(text)


func _clear_hint() -> void:
	var hud := get_node_or_null("/root/World3/PlayerHUD")
	if hud and hud.has_method("show_hint"):
		hud.show_hint("")
