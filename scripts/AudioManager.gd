extends Node
## Audio manager autoload. Plays one-shot sounds from the 400 Sounds Pack.
## Usage: AudioManager.play("sword_clash") or AudioManager.play("dice_roll")

# Map of sound names to file paths. Arrays pick a random variant.
const SOUNDS: Dictionary = {
	# Combat
	"dice_roll": [
		"res://Sounds/400 Sounds Pack/Card and Board/dice_roll_1.wav",
		"res://Sounds/400 Sounds Pack/Card and Board/dice_roll_2.wav",
		"res://Sounds/400 Sounds Pack/Card and Board/dice_roll_3.wav",
		"res://Sounds/400 Sounds Pack/Card and Board/dice_roll_4.wav",
	],
	"sword_clash": [
		"res://Sounds/400 Sounds Pack/Weapons/sword_clash.wav",
		"res://Sounds/400 Sounds Pack/Weapons/sword_clash_2.wav",
	],
	"sword_slice": "res://Sounds/400 Sounds Pack/Weapons/sword_slice.wav",
	"enemy_damage": [
		"res://Sounds/400 Sounds Pack/Combat and Gore/crunch.wav",
		"res://Sounds/400 Sounds Pack/Combat and Gore/crunch_quick.wav",
	],
	"player_damage": "res://Sounds/400 Sounds Pack/Combat and Gore/squelching_1.wav",
	"enemy_death": [
		"res://Sounds/400 Sounds Pack/Combat and Gore/crunch_splat.wav",
		"res://Sounds/400 Sounds Pack/Combat and Gore/crunch_splat_2.wav",
	],
	"flee": "res://Sounds/400 Sounds Pack/Materials/paper_tear_1.wav",
	"boss_flame": "res://Sounds/400 Sounds Pack/Combat and Gore/splat_double_quick.wav",
	"combat_start": "res://Sounds/400 Sounds Pack/Weapons/sword_unsheath.wav",

	# UI
	"ui_click": [
		"res://Sounds/400 Sounds Pack/UI/pop_1.wav",
		"res://Sounds/400 Sounds Pack/UI/pop_2.wav",
		"res://Sounds/400 Sounds Pack/UI/pop_3.wav",
		"res://Sounds/400 Sounds Pack/UI/pop_4.wav",
	],
	"ui_toggle": "res://Sounds/400 Sounds Pack/UI/click_double_on.wav",

	# Items / pickups
	"gold_pickup": [
		"res://Sounds/400 Sounds Pack/Items/coins_gather_small.wav",
		"res://Sounds/400 Sounds Pack/Items/coin_jingle_small.wav",
	],
	"item_pickup": "res://Sounds/400 Sounds Pack/Weapons/weapon_pick_up.wav",
	"weapon_equip": "res://Sounds/400 Sounds Pack/Weapons/weapon_equip.wav",
	"weapon_unequip": "res://Sounds/400 Sounds Pack/Weapons/weapon_unequip.wav",
	"item_use": "res://Sounds/400 Sounds Pack/Items/page_turn.wav",

	# Environment / dungeon
	"door_open": "res://Sounds/400 Sounds Pack/Environment/lock_unlock.wav",
	"door_sealed": "res://Sounds/400 Sounds Pack/Environment/lock_lock.wav",
	"trap_trigger": "res://Sounds/400 Sounds Pack/Combat and Gore/splat_quick.wav",
	"healing_spring": "res://Sounds/400 Sounds Pack/Musical Effects/8_bit_chime_positive.wav",

	# UI panels
	"inventory_open": "res://Sounds/400 Sounds Pack/Items/book_open.wav",
	"inventory_close": "res://Sounds/400 Sounds Pack/Items/book_close.wav",
	"map_open": "res://Sounds/400 Sounds Pack/Items/map_open.wav",
	"map_close": "res://Sounds/400 Sounds Pack/Items/map_close.wav",
	"shop_open": "res://Sounds/400 Sounds Pack/Items/coins_gather_medium.wav",
	"merchant_greet": "res://Sounds/400 Sounds Pack/Human/cough_double.wav",
	"shop_transaction": "res://Sounds/400 Sounds Pack/Items/coins_gather_quick.wav",

	# Musical stings
	"victory": "res://Sounds/400 Sounds Pack/Musical Effects/grand_piano_level_complete.wav",
	"game_over": "res://Sounds/400 Sounds Pack/Musical Effects/grand_piano_defeated.wav",
	"boss_reveal": "res://Sounds/400 Sounds Pack/Musical Effects/brass_negative.wav",
	"boss_awaken": "res://Sounds/400 Sounds Pack/Musical Effects/8_bit_negative_long.wav",
	"treasure_found": "res://Sounds/400 Sounds Pack/Musical Effects/music_box_chime_positive.wav",
	"game_start": "res://Sounds/400 Sounds Pack/Musical Effects/8_bit_chime_positive.wav",
	"dungeon_enter": "res://Sounds/400 Sounds Pack/Musical Effects/music_box_level_start.wav",
}

var _players: Array[AudioStreamPlayer] = []
var _next_player: int = 0
const MAX_PLAYERS: int = 8


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in range(MAX_PLAYERS):
		var p := AudioStreamPlayer.new()
		p.name = "SFX_%d" % i
		p.bus = "Master"
		add_child(p)
		_players.append(p)


## Play a one-shot sound by name. Volume in dB (default 0.0).
func play(sound_name: String, volume_db: float = 0.0) -> void:
	var path = SOUNDS.get(sound_name, "")
	if typeof(path) == TYPE_STRING and (path as String).is_empty():
		push_warning("[AudioManager] Unknown sound: %s" % sound_name)
		return
	if path == null:
		push_warning("[AudioManager] Unknown sound: %s" % sound_name)
		return

	# Pick random variant if it's an array
	if typeof(path) == TYPE_ARRAY:
		var arr: Array = path as Array
		if arr.is_empty(): return
		path = arr[randi() % arr.size()]

	var stream: AudioStream = load(path as String) as AudioStream
	if stream == null:
		push_warning("[AudioManager] Failed to load: %s" % path)
		return

	var player: AudioStreamPlayer = _players[_next_player]
	_next_player = (_next_player + 1) % MAX_PLAYERS

	# If this player is already playing, stop it (round-robin override)
	if player.playing:
		player.stop()
	player.stream = stream
	player.volume_db = volume_db
	player.play()
