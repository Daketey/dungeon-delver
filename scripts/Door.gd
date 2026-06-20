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
