extends Node
class_name CombatManager

signal combat_started(player: CharacterBody3D, enemy: CharacterBody3D)
signal combat_ended(player: CharacterBody3D, enemy: CharacterBody3D, victory: bool)
signal combat_log(message: String)
signal combat_update(player: CharacterBody3D, enemy: CharacterBody3D)
signal dice_rolled(hit: int, damage: int, defense: int)

var _player: CharacterBody3D = null
var _enemy: CharacterBody3D = null
var _combat_active: bool = false
var _enemy_paralyzed: bool = false
var _feats: Array = []
var _feats_remaining: int = 0
var _boss_fight: bool = false

var last_hit_roll: int = 0
var last_damage_roll: int = 0
var last_defense_roll: int = 0
var dice_are_fresh: bool = false

func _ready() -> void:
	randomize()

func roll_die(sides: int) -> int:
	return randi() % sides + 1

func start_combat(player: CharacterBody3D, enemy: CharacterBody3D) -> void:
	if _combat_active: return
	if player == null or enemy == null: return
	_player = player; _enemy = enemy; _combat_active = true
	_feats = player.heroic_feats.duplicate()
	_feats_remaining = 1 + ResourceStash.bonus_heroic_feats
	_boss_fight = "enemy_name" in enemy and enemy.enemy_name == "Greater Demon"
	_log("Combat: %s (lvl %d) vs %s (lvl %d)" % [_player.name, _player.level, _enemy.name, _enemy.level])
	emit_signal("combat_started", _player, _enemy)
	emit_signal("combat_update", _player, _enemy)

func roll_dice() -> void:
	if not _combat_active or _player == null or _enemy == null: return
	if _player.health <= 0 or _enemy.health <= 0: return
	last_hit_roll = roll_die(8); last_damage_roll = roll_die(6); last_defense_roll = roll_die(4)
	dice_are_fresh = true
	_log("Dice: d8:%d  d6:%d  d4:%d" % [last_hit_roll, last_damage_roll, last_defense_roll])
	emit_signal("dice_rolled", last_hit_roll, last_damage_roll, last_defense_roll)

func swap_dice(idx_a: int, idx_b: int) -> bool:
	if not dice_are_fresh or _feats_remaining <= 0: return false
	var dice := [last_hit_roll, last_damage_roll, last_defense_roll]
	var tmp: int = dice[idx_a]; dice[idx_a] = dice[idx_b]; dice[idx_b] = tmp
	last_hit_roll = dice[0]; last_damage_roll = dice[1]; last_defense_roll = dice[2]
	_feats_remaining -= 1
	_log("Feat used! -> d8:%d  d6:%d  d4:%d" % [last_hit_roll, last_damage_roll, last_defense_roll])
	emit_signal("dice_rolled", last_hit_roll, last_damage_roll, last_defense_roll)
	emit_signal("combat_update", _player, _enemy)
	return true

func resolve_turn() -> void:
	if not _combat_active or _player == null or _enemy == null: return
	if not dice_are_fresh: return
	dice_are_fresh = false

	var hit: int = last_hit_roll; var dmg: int = last_damage_roll + ResourceStash.bonus_damage; var dfn: int = last_defense_roll
	hit += ResourceStash.bonus_hit

	if _boss_fight and last_hit_roll == 1:
		_player.health = max(0, _player.health - 4)
		_log("Infernal Flame! The Greater Demon burns you for 4 damage!")
		emit_signal("combat_update", _player, _enemy); _check_end(); return

	if last_hit_roll == 8: var reroll := roll_die(6) + ResourceStash.bonus_damage; _log("Natural 8! Re-roll -> %d" % reroll); dmg = reroll
	if last_hit_roll == 1: var s := dmg; dmg = dfn; dfn = s; _log("Natural 1! Swapped dmg/def")

	if _enemy_paralyzed:
		_enemy_paralyzed = false
		_log("Enemy is paralyzed and cannot attack!")
		emit_signal("combat_update", _player, _enemy)
		_check_end()
		return

	if hit >= _enemy.level:
		var atk: int = dmg + _player.damage_mod; var blk: int = dfn + _enemy.defense_mod; var net: int = max(atk - blk, 0)
		_enemy.health = max(_enemy.health - net, 0)
		_log("You hit for %d (%d - %d). Enemy HP: %d" % [net, atk, blk, _enemy.health])
	else:
		var ed: int = roll_die(6) + _enemy.damage_mod; var eb: int = dfn + _player.defense_mod + ResourceStash.bonus_defense; var net: int = max(ed - eb, 0)
		_player.health = max(_player.health - net, 0)
		_log("Enemy hits for %d (%d - %d). Your HP: %d" % [net, ed, eb, _player.health])

	emit_signal("combat_update", _player, _enemy); _check_end()

func _check_end() -> void:
	if _player.health <= 0 or _enemy.health <= 0: _finish(_enemy.health <= 0)

func feats_remaining() -> int: return _feats_remaining

func flee() -> bool:
	if not _combat_active: return false
	var dmg: int = roll_die(4)
	_player.health = max(0, _player.health - dmg)
	if _enemy: _enemy.health = _enemy.max_health  # Enemy stays at full HP
	_log("Fled! Took %d damage. Enemy restored to full health." % dmg)
	_finish(false)
	return true

func use_consumable(_item_name: String) -> bool: return _combat_active

## Scroll: paralyze enemy — skips their next attack.
func apply_paralysis() -> void:
	_enemy_paralyzed = true
	_log("Enemy paralyzed! It loses its next attack.")

## Scroll: lightning bolt — deals d4+2 to enemy.
func apply_lightning() -> int:
	var dmg: int = roll_die(4) + 2
	_enemy.health = max(_enemy.health - dmg, 0)
	_log("Lightning strikes for %d damage! Enemy HP: %d" % [dmg, _enemy.health])
	emit_signal("combat_update", _player, _enemy)
	_check_end()
	return dmg

func _finish(victory: bool) -> void:
	var pr = _player; var er = _enemy
	_combat_active = false; dice_are_fresh = false
	_log("Victory!" if victory else "Defeat!")
	pr.heroic_feats = _feats
	# Decrement 2-use scroll buffs
	if victory and ResourceStash.temp_buffs.has("defense_plus1"):
		ResourceStash.temp_buffs["defense_plus1"] -= 1
		if ResourceStash.temp_buffs["defense_plus1"] <= 0:
			ResourceStash.temp_buffs.erase("defense_plus1")
			_log("Stoneskin has worn off.")
	if victory and ResourceStash.temp_buffs.has("damage_plus1"):
		ResourceStash.temp_buffs["damage_plus1"] -= 1
		if ResourceStash.temp_buffs["damage_plus1"] <= 0:
			ResourceStash.temp_buffs.erase("damage_plus1")
			_log("Strength scroll has worn off.")
	emit_signal("combat_ended", pr, er, victory)
	_player = null; _enemy = null; _feats = []

func is_active() -> bool: return _combat_active

func _log(message: String) -> void: emit_signal("combat_log", message)
