extends Node2D

## Minimal turn-based battle: Attack/Run against one enemy, no animation,
## ASCII-consistent (text-only UI). GameState.pending_battle_enemy names
## which data/enemies/*.json to load. See PROGRESS.md for what's still
## missing (multiple enemies, rewards, a real game-over state).

const ENEMY_DATA_DIR := "res://data/enemies/"

@onready var status_label: Label = $UI/Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var log_label: RichTextLabel = $UI/Panel/MarginContainer/VBoxContainer/LogLabel
@onready var actions_container: HBoxContainer = $UI/Panel/MarginContainer/VBoxContainer/ActionsContainer

var enemy_name: String = "Enemy"
var enemy_glyph: String = "?"
var enemy_hp: int = 10
var enemy_max_hp: int = 10
var enemy_attack: int = 3

var _battle_over: bool = false


func _ready() -> void:
	var enemy_id: String = GameState.pending_battle_enemy
	if enemy_id == "":
		enemy_id = "slime"
	_load_enemy(enemy_id)
	_log("A wild %s (%s) appears!" % [enemy_name, enemy_glyph])
	_update_status()


func _load_enemy(enemy_id: String) -> void:
	var path := ENEMY_DATA_DIR + enemy_id + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Battle: could not open enemy data file: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Battle: invalid enemy data file: %s" % path)
		return
	enemy_name = parsed.get("name", "Enemy")
	enemy_glyph = parsed.get("glyph", "?")
	enemy_hp = parsed.get("hp", 10)
	enemy_max_hp = enemy_hp
	enemy_attack = parsed.get("attack", 3)


func _log(line: String) -> void:
	log_label.text += line + "\n"


func _update_status() -> void:
	status_label.text = "@ You  HP: %d/%d      %s %s  HP: %d/%d" % [
		GameState.player_hp, GameState.player_max_hp,
		enemy_glyph, enemy_name, enemy_hp, enemy_max_hp,
	]


func _on_attack_button_pressed() -> void:
	if _battle_over:
		return
	enemy_hp = max(0, enemy_hp - GameState.player_attack)
	_log("You attack %s for %d damage." % [enemy_name, GameState.player_attack])
	if enemy_hp == 0:
		_update_status()
		_log("%s is defeated! You win." % enemy_name)
		_end_battle()
		return
	GameState.player_hp = max(0, GameState.player_hp - enemy_attack)
	_log("%s attacks you for %d damage." % [enemy_name, enemy_attack])
	_update_status()
	if GameState.player_hp == 0:
		_log("You were defeated... you crawl back to the village.")
		GameState.player_hp = GameState.player_max_hp
		_end_battle()


func _on_run_button_pressed() -> void:
	if _battle_over:
		return
	_log("You run away.")
	_end_battle()


func _end_battle() -> void:
	_battle_over = true
	for child in actions_container.get_children():
		child.disabled = true
	GameState.save_game()
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file.bind("res://scenes/Main.tscn").call_deferred()
