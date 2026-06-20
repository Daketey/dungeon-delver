extends CharacterBody3D
class_name EnemyPlaceholder
## Enemy with Sprite3D â€” texture updated from data, scene handles all positioning/scale.

@export var level: int = 1
@export var max_health: int = 6
@export var damage_mod: int = 0
@export var defense_mod: int = 0
var health: int = 0
var heroic_feats: Array = []

var enemy_name: String = "Enemy"
var treasure_drop_min: int = 0

func _ready() -> void:
	health = max_health

func init_from_data(data: Dictionary) -> void:
	enemy_name = data.get("name", "Enemy")
	level = data.get("level", 1)
	max_health = data.get("hp", 6)
	health = max_health
	damage_mod = data.get("attack", 0)
	defense_mod = data.get("defense", 0)
	treasure_drop_min = data.get("treasure_min", 0)
	name = enemy_name
	# Update the existing Sprite3D child's texture
	var sprite_path: String = data.get("sprite", "")
	if sprite_path != "":
		var sprite: Sprite3D = $Sprite3D as Sprite3D
		var tex := load(sprite_path) as Texture2D
		if tex: sprite.texture = tex

	# Apply enemy-specific scale
	var sc: float = data.get("sprite_scale", 1.0)
	$Sprite3D.scale *= sc

func _physics_process(_delta: float) -> void:
	var player := _find_player()
	if player:
		look_at(player.global_position, Vector3.UP)
		rotation_degrees.x = 0
		rotation_degrees.z = 0

var entity_key: String = ""

func _find_player() -> Node3D:
	var root := get_tree().get_root()
	if root:
		var p := root.get_node_or_null("World3/Player")
		if p: return p as Node3D
	return null
