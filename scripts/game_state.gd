extends Node

## Autoload singleton. Tracks story flags (e.g. "met_elder") set by dialogue
## nodes via "set_flag", checked by choices via "requires_flag" /
## "requires_not_flag". Persisted immediately on every change — this is a
## minimal save system covering flags only; player position/inventory/etc.
## aren't tracked yet (see PROGRESS.md Next up).

const SAVE_PATH := "user://save.json"

var flags: Dictionary = {}


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
	file.store_string(JSON.stringify({"flags": flags}))
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
