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


## Called by help_overlay.gd while the help overlay is open. Every raw
## _unhandled_input handler in the project already checks is_help_open
## (see PROGRESS.md's "help page" entry — the last two that didn't got
## fixed there), but a focused Button's own `pressed` signal fires
## straight off the built-in ui_accept action through Godot's UI focus
## system, bypassing all of those checks entirely — a dialogue choice or
## pause-menu button could still be "clicked" via Z while help was drawn
## on top of it. Pulling Z/X out of ui_accept/ui_cancel for as long as
## help is open closes that gap at the source, for every Button-based
## screen at once, without needing to touch SceneTree.paused (which the
## pause menu already manages on its own — doing the same thing here too
## would risk the two stepping on each other if help is ever opened
## while already paused).
func suspend_ui_keys() -> void:
	InputMap.action_erase_event("ui_accept", _key_event(KEY_Z))
	InputMap.action_erase_event("ui_cancel", _key_event(KEY_X))


func restore_ui_keys() -> void:
	if not InputMap.action_has_event("ui_accept", _key_event(KEY_Z)):
		InputMap.action_add_event("ui_accept", _key_event(KEY_Z))
	if not InputMap.action_has_event("ui_cancel", _key_event(KEY_X)):
		InputMap.action_add_event("ui_cancel", _key_event(KEY_X))
