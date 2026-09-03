extends Node2D

@onready var subtitle_label: Label = $CanvasLayer/VBoxContainer/SubtitleLabel
@onready var continue_button: Button = $CanvasLayer/VBoxContainer/ContinueButton
@onready var new_game_button: Button = $CanvasLayer/VBoxContainer/NewGameButton


func _ready() -> void:
	# The title itself ("WANDERER'S VILLAGE") is a proper-noun logo, kept
	# untranslated; everything else here localizes.
	subtitle_label.text = Localization.t("title.subtitle")
	continue_button.text = Localization.t("title.continue")
	new_game_button.text = Localization.t("title.new_game")
	if not GameState.has_saved_position:
		continue_button.hide()
	new_game_button.grab_focus()


func _on_continue_button_pressed() -> void:
	get_tree().change_scene_to_file.bind("res://scenes/Main.tscn").call_deferred()


func _on_new_game_button_pressed() -> void:
	GameState.reset_new_game()
	get_tree().change_scene_to_file.bind("res://scenes/Main.tscn").call_deferred()
