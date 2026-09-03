extends Node

## Autoload singleton. Establishes the game's fixed keyboard scheme: arrow
## keys move, Z confirms/interacts/attacks, X cancels/runs/closes, H toggles
## the help overlay, Esc pauses. Adding Z/X to the built-in ui_accept/
## ui_cancel actions here (rather than per-screen) means every existing
## Button-based screen (dialogue choices, pause menu, battle actions, title
## menu) picks up Z/X for free through Godot's own focus/action system.

var is_help_open: bool = false


func _ready() -> void:
	InputMap.action_add_event("ui_accept", _key_event(KEY_Z))
	InputMap.action_add_event("ui_cancel", _key_event(KEY_X))


func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = keycode
	return event
