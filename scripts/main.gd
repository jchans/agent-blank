extends Node2D

## Spawns one NPC per JSON file under data/npcs/. Creating a new NPC in the
## game requires no scene editing: drop a new JSON file in data/npcs/ (see
## data/npcs/elder.json for the shape) and a matching dialogue graph under
## dialogues/.

const NPC_SCENE := preload("res://scenes/NPC.tscn")
const NPC_DATA_DIR := "res://data/npcs/"


func _ready() -> void:
	_spawn_npcs()


func _spawn_npcs() -> void:
	var dir := DirAccess.open(NPC_DATA_DIR)
	if dir == null:
		push_warning("Main: could not open NPC data dir: %s" % NPC_DATA_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_spawn_npc_from_file(NPC_DATA_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _spawn_npc_from_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Main: could not open NPC data file: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Main: invalid NPC data file: %s" % path)
		return

	var npc := NPC_SCENE.instantiate()
	var pos: Array = parsed.get("position", [0, 0])
	npc.position = Vector2(pos[0], pos[1])
	var col: Array = parsed.get("color", [1, 1, 1, 1])
	npc.portrait_color = Color(col[0], col[1], col[2], col[3] if col.size() > 3 else 1.0)
	npc.npc_name = parsed.get("name", "NPC")
	npc.dialogue_path = parsed.get("dialogue", "")
	npc.name = String(parsed.get("id", "NPC"))
	add_child(npc)
