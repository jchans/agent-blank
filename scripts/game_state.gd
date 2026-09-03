extends Node

## Autoload singleton. Tracks story flags and basic player battle stats,
## persisted immediately to user://save.json on every change. Inventory
## isn't tracked yet (see PROGRESS.md Next up) — keep the save format
## additive when adding it, don't redesign it.

const SAVE_PATH := "user://save.json"

var flags: Dictionary = {}
var player_max_hp: int = 20
var player_hp: int = 20
var player_attack: int = 5

## Kept in sync from Main._process() while the overworld is loaded; written
## to save.json whenever save_game() runs (flag change, battle end, pause).
## Default matches Main.tscn's current spawn point.
var player_position: Vector2 = Vector2(300, 180)
## True once a save was actually loaded with a player_position in it —
## distinguishes "fresh game, use the scene's default spawn" from "resume
## a save, override the spawn".
var has_saved_position: bool = false

## Which data/maps/<id>.txt room the player is in. Set by Main whenever it
## loads a room (initial load and door transitions), read at startup to
## pick the room a saved game resumes into.
var current_map: String = "village"

## Set by whoever triggers a battle (e.g. DialogueManager on a "start_battle"
## node) right before changing to Battle.tscn; Battle reads it in _ready().
var pending_battle_enemy: String = ""
## Optional flag name set via set_flag() when the upcoming battle is won —
## e.g. a dialogue node's "victory_flag" field (see dialogue_manager.gd).
## Empty means no flag to set. Not persisted (transient, like the above).
var pending_victory_flag: String = ""


func _ready() -> void:
	load_game()


## Resets in-memory state to a fresh game's defaults, without touching the
## save file on disk — a subsequent set_flag()/save_game() call (or the
## first pause/battle/etc.) will overwrite it. Used by the title screen's
## "New Game" so an existing save doesn't force "Continue".
func reset_new_game() -> void:
	flags = {}
	player_max_hp = 20
	player_hp = 20
	player_attack = 5
	player_position = Vector2(300, 180)
	has_saved_position = false
	current_map = "village"


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
		"player_position": [player_position.x, player_position.y],
		"current_map": current_map,
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
		var pos: Array = parsed.get("player_position", [])
		if pos.size() == 2:
			player_position = Vector2(pos[0], pos[1])
			has_saved_position = true
		current_map = parsed.get("current_map", current_map)
