class_name Merchant
extends CharacterBody3D

const SPEED = 5.0
const JUMP_VELOCITY = 4.5

@export var player_char: CharacterBody3D

var shadow: MeshInstance3D

func _ready() -> void:
	_create_shadow()

func _physics_process(delta: float) -> void:
	if player_char == null:
		return
	var dir: Vector3 = player_char.global_position - global_position
	dir.y = 0.0
	dir = dir.normalized()
	var target: Vector3 = global_position + dir
	look_at(target, Vector3.UP)

func _create_shadow() -> void:
	if shadow != null:
		return
	shadow = MeshInstance3D.new()
	var mesh: QuadMesh = QuadMesh.new()
	mesh.size = Vector2(1.4, 1.4)
	shadow.mesh = mesh
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color = Color(0.0, 0.0, 0.0, 0.55)
	material.flags_unshaded = true
	material.flags_transparent = true
	material.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_ALWAYS
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.render_priority = 1
	shadow.material_override = material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	shadow.position = Vector3(0.0, -0.1, 0.0)
	shadow.name = "DropShadow"
	add_child(shadow)
