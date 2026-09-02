extends Node2D

@onready var prompt_label: Label = $CanvasLayer/VBoxContainer/PromptLabel


func _ready() -> void:
	if GameState.has_saved_position:
		prompt_label.text = "Press Enter to Continue"
	else:
		prompt_label.text = "Press Enter to Start"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			get_tree().change_scene_to_file.bind("res://scenes/Main.tscn").call_deferred()
			get_viewport().set_input_as_handled()
