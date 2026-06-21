extends Node3D
class_name Cell

const DEBUG := false

@onready var topFace = $TopFace
@onready var northFace = $NorthFace
@onready var eastFace = $EastFace
@onready var southFace = $SouthFace
@onready var westFace = $WestFace
@onready var bottomFace = $BottomFace

func update_faces(cell_list) -> void:
	var my_grid_position = Vector2i(position.x/Globals.GRID_SIZE, position.z/Globals.GRID_SIZE)

	if cell_list.has(my_grid_position + Vector2i.RIGHT):
		eastFace.find_child("CollisionShape3D").disabled = true
		eastFace.queue_free()
	if cell_list.has(my_grid_position + Vector2i.LEFT):
		westFace.find_child("CollisionShape3D").disabled = true
		westFace.queue_free()
	if cell_list.has(my_grid_position + Vector2i.DOWN):
		southFace.find_child("CollisionShape3D").disabled = true
		southFace.queue_free()
	if cell_list.has(my_grid_position + Vector2i.UP):
		northFace.find_child("CollisionShape3D").disabled = true
		northFace.queue_free()

	if DEBUG:
		var removed: Array[String] = []
		if cell_list.has(my_grid_position + Vector2i.RIGHT): removed.append("E")
		if cell_list.has(my_grid_position + Vector2i.LEFT): removed.append("W")
		if cell_list.has(my_grid_position + Vector2i.DOWN): removed.append("S")
		if cell_list.has(my_grid_position + Vector2i.UP): removed.append("N")
		var kept: String = ""
		if not "E" in removed: kept += "E"
		if not "W" in removed: kept += "W"
		if not "S" in removed: kept += "S"
		if not "N" in removed: kept += "N"
		if kept == "": kept = "none"
		print("Cell (%d,%d) removed:[%s] kept:[%s]" % [my_grid_position.x, my_grid_position.y, ", ".join(removed), kept])

		var label := Label3D.new()
		label.name = "CellLabel"
		label.text = "(%d,%d)" % [my_grid_position.x, my_grid_position.y]
		label.font_size = 18
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(0, 1.5, 0)
		label.modulate = Color.GREEN
		add_child(label)


## Tint wall faces with a per-room modulate color. Duplicates the
## shared material so each room instance is visually distinct.
func apply_tint(color: Color) -> void:
	for face: MeshInstance3D in [topFace, northFace, eastFace, southFace, westFace, bottomFace]:
		if not is_instance_valid(face):
			continue
		var mat := face.get_surface_override_material(0)
		if mat:
			mat = mat.duplicate()
			mat.albedo_color = color
			face.set_surface_override_material(0, mat)
