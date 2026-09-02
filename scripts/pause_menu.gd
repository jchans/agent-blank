extends Control

## Lives in Main.tscn's CanvasLayer. process_mode = ALWAYS so this keeps
## reading input while SceneTree.paused is true (everything else stops by
## default, since Godot's default node process_mode is PAUSABLE-equivalent).

@onready var resume_button: Button = $Panel/MarginContainer/VBoxContainer/ResumeButton
@onready var quit_button: Button = $Panel/MarginContainer/VBoxContainer/QuitButton


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS


func _unhandled_input(event: InputEvent) -> void:
	if DialogueManager.is_active and not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	if visible:
		_resume()
	else:
		_pause()


func _pause() -> void:
	get_tree().paused = true
	show()


func _resume() -> void:
	get_tree().paused = false
	hide()


func _on_resume_button_pressed() -> void:
	_resume()


func _on_quit_button_pressed() -> void:
	get_tree().quit()
