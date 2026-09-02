extends Node

## Autoload singleton. Tracks story flags and basic player battle stats,
## persisted immediately to user://save.json on every change. Player
## position/inventory/current map aren't tracked yet (see PROGRESS.md
## Next up) — keep the save format additive when adding those, don't
## redesign it.

const SAVE_PATH := "user://save.json"

var flags: Dictionary = {}
var player_max_hp: int = 20
var player_hp: int = 20
var player_attack: int = 5
var gold: int = 0

## Set by whoever triggers a battle (e.g. DialogueManager on a "start_battle"
## node) right before changing to Battle.tscn; Battle reads it in _ready().
var pending_battle_enemy: String = ""


func _ready() -> void:
	load_game()


func set_flag(flag_name: String) -> void:
	flags[flag_name] = true
	save_game()


func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameState: could not open save file for writing: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify({
		"flags": flags,
		"player_hp": player_hp,
		"player_max_hp": player_max_hp,
		"player_attack": player_attack,
		"gold": gold,
	}))
	file.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		flags = parsed.get("flags", {})
		player_hp = parsed.get("player_hp", player_hp)
		player_max_hp = parsed.get("player_max_hp", player_max_hp)
		player_attack = parsed.get("player_attack", player_attack)
		gold = parsed.get("gold", gold)
