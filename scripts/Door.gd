extends Node3D
class_name Door


func _ready() -> void:
	# Lock wall collision to player layer — editor keeps changing the tscn
	var sb := get_node_or_null("MeshInstance3D/StaticBody3D") as StaticBody3D
	if sb:
		sb.collision_layer = 1
		sb.collision_mask = 0


func update_faces(_cell_list: Array) -> void:
	pass


## Tint the door material with a per-room modulate color. Deep-duplicates
## so the next_pass chain also gets a unique copy.
func apply_tint(color: Color) -> void:
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var mat: StandardMaterial3D = mesh.get_surface_override_material(0)
		if mat:
			mat = mat.duplicate(true) as StandardMaterial3D
			mat.albedo_color = color
			# Also tint the next_pass material so both passes match
			if mat.next_pass:
				mat.next_pass.albedo_color = color
			mesh.set_surface_override_material(0, mat)
