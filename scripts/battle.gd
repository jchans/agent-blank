extends Node2D

## Minimal turn-based battle: Attack/Run against one enemy, no animation,
## ASCII-consistent (text-only UI). GameState.pending_battle_enemy names
## which data/enemies/*.json to load. See PROGRESS.md for what's still
## missing (multiple enemies, rewards, a real game-over state).

const ENEMY_DATA_DIR := "res://data/enemies/"

@onready var status_label: Label = $UI/Panel/MarginContainer/VBoxContainer/StatusLabel
@onready var log_label: RichTextLabel = $UI/Panel/MarginContainer/VBoxContainer/LogLabel
@onready var actions_container: HBoxContainer = $UI/Panel/MarginContainer/VBoxContainer/ActionsContainer
@onready var attack_button: Button = $UI/Panel/MarginContainer/VBoxContainer/ActionsContainer/AttackButton
@onready var run_button: Button = $UI/Panel/MarginContainer/VBoxContainer/ActionsContainer/RunButton

var enemy_name: String = "Enemy"
var enemy_glyph: String = "?"
var enemy_hp: int = 10
var enemy_max_hp: int = 10
var enemy_attack: int = 3

var _battle_over: bool = false


func _ready() -> void:
	attack_button.text = Localization.t("battle.attack_button")
	run_button.text = Localization.t("battle.run_button")
	var enemy_id: String = GameState.pending_battle_enemy
	if enemy_id == "":
		enemy_id = "slime"
	_load_enemy(enemy_id)
	_log(Localization.t("battle.appears") % [enemy_name, enemy_glyph])
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
	status_label.text = Localization.t("battle.status") % [
		GameState.player_hp, GameState.player_max_hp,
		enemy_glyph, enemy_name, enemy_hp, enemy_max_hp,
	]


func _unhandled_input(event: InputEvent) -> void:
	if _battle_over or Controls.is_help_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			_on_attack_button_pressed()
			get_viewport().set_input_as_handled()
		elif event.keycode == KEY_X:
			_on_run_button_pressed()
			get_viewport().set_input_as_handled()


func _on_attack_button_pressed() -> void:
	if _battle_over:
		return
	enemy_hp = max(0, enemy_hp - GameState.player_attack)
	_log(Localization.t("battle.attack_hit") % [enemy_name, GameState.player_attack])
	if enemy_hp == 0:
		_update_status()
		_log(Localization.t("battle.win") % enemy_name)
		if GameState.pending_victory_flag != "":
			GameState.set_flag(GameState.pending_victory_flag)
			GameState.pending_victory_flag = ""
		_end_battle()
		return
	GameState.player_hp = max(0, GameState.player_hp - enemy_attack)
	_log(Localization.t("battle.enemy_hit") % [enemy_name, enemy_attack])
	_update_status()
	if GameState.player_hp == 0:
		_log(Localization.t("battle.lose"))
		GameState.player_hp = GameState.player_max_hp
		_end_battle()


func _on_run_button_pressed() -> void:
	if _battle_over:
		return
	_log(Localization.t("battle.run"))
	_end_battle()


func _end_battle() -> void:
	_battle_over = true
	for child in actions_container.get_children():
		child.disabled = true
	GameState.save_game()
	await get_tree().create_timer(1.5).timeout
	get_tree().change_scene_to_file.bind("res://scenes/Main.tscn").call_deferred()
