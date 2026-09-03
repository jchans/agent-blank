extends Node2D

@onready var continue_button: Button = $CanvasLayer/VBoxContainer/ContinueButton
@onready var new_game_button: Button = $CanvasLayer/VBoxContainer/NewGameButton


func _ready() -> void:
	if GameState.has_saved_position:
		continue_button.grab_focus()
	else:
		continue_button.hide()
		new_game_button.grab_focus()


func _on_continue_button_pressed() -> void:
	get_tree().change_scene_to_file.bind("res://scenes/Main.tscn").call_deferred()


func _on_new_game_button_pressed() -> void:
	GameState.reset_new_game()
	get_tree().change_scene_to_file.bind("res://scenes/Main.tscn").call_deferred()
