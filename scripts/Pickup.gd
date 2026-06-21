extends Area3D
## Physical collectible. Player walks over it to pick up.

var item_data: Dictionary = {}
var is_gold: bool = false
var gold_amount: int = 0
var bob_offset: float = 0.0

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	bob_offset = randf() * TAU
	monitoring = true
	monitorable = false

func _process(delta: float) -> void:
	bob_offset += delta * 2.5
	position.y = 0.15 + sin(bob_offset) * 0.08

func init_gold(amount: int) -> void:
	is_gold = true
	gold_amount = amount
	_create_mesh(Color(1.0, 0.85, 0.1), 0.18, 0.06)
	name = "GoldPile"

func init_item(data: Dictionary) -> void:
	item_data = data.duplicate()
	name = data.get("name", "Item")
	var col := Color.WHITE
	var effect: String = data.get("effect", "")
	if effect.begins_with("heal"):
		col = Color(0.2, 0.9, 0.3)
	elif effect.begins_with("damage") or effect.begins_with("defense"):
		col = Color(0.3, 0.5, 1.0)
	elif effect == "max_hp_plus1_fullheal":
		col = Color(1.0, 0.9, 0.1)
	elif data.get("slot", "") != "":
		col = Color(0.7, 0.7, 0.75)
	_create_mesh(col, 0.2, 0.3)

func _create_mesh(col: Color, radius: float, height: float) -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	mi.mesh = cyl
	var mat := StandardMaterial3D.new()
	mat.albedo_color = col
	mat.metallic = 0.6 if is_gold else 0.1
	mat.roughness = 0.3
	mi.material_override = mat
	mi.rotation_degrees = Vector3(90, 0, 0)
	add_child(mi)
	var cs := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 0.5
	shape.height = 0.5
	cs.shape = shape
	add_child(cs)

var _collected: bool = false

func _on_body_entered(body: Node3D) -> void:
	if _collected or not body is GridPlayer:
		return
	_collected = true
	monitoring = false
	if is_gold:
		AudioManager.play("gold_pickup")
		ResourceStash.add_gold(gold_amount)
		_show_notify("Picked up %d gold!" % gold_amount, Color.GOLD)
	else:
		AudioManager.play("item_pickup")
		ResourceStash.add_item(item_data)
		_show_notify("Picked up %s!" % item_data.get("name", "item"), Color.GOLD)
	queue_free()


func _show_notify(text: String, color: Color) -> void:
	var hud := get_node_or_null("/root/World3/PlayerHUD")
	if hud and hud.has_method("show_notification"):
		hud.show_notification(text, color)
