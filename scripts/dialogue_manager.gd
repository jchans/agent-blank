extends Node

## Autoload singleton. Drives a branching dialogue graph loaded from JSON
## and reports state to whatever DialogueBox registers itself.

signal dialogue_started
signal dialogue_ended

var is_active: bool = false

var _dialogue_data: Dictionary = {}
var _current_node_id: String = ""
var _dialogue_box: Control = null


func register_dialogue_box(box: Control) -> void:
	_dialogue_box = box


func start_dialogue(dialogue_path: String) -> void:
	if _dialogue_box == null:
		push_warning("DialogueManager: no dialogue box registered")
		return
	var file := FileAccess.open(dialogue_path, FileAccess.READ)
	if file == null:
		push_error("DialogueManager: could not open dialogue file: %s" % dialogue_path)
		return
	var text := file.get_as_text()
	file.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("DialogueManager: invalid dialogue JSON: %s" % dialogue_path)
		return
	_dialogue_data = parsed
	_current_node_id = _dialogue_data.get("start", "")
	is_active = true
	dialogue_started.emit()
	_dialogue_box.show()
	_show_current_node()


## A one-off announcement (e.g. an item pickup) that reuses the dialogue
## box's display/typewriter/advance machinery instead of a real branching
## graph: a single speakerless node with no "next", so the player's next
## Z press (after the typewriter finishes) naturally ends it via the
## dangling-next path in _show_current_node/advance below.
func show_message(text: String) -> void:
	if _dialogue_box == null:
		push_warning("DialogueManager: no dialogue box registered")
		return
	_dialogue_data = {"start": "message", "nodes": {"message": {"speaker": "", "text": text}}}
	_current_node_id = "message"
	is_active = true
	dialogue_started.emit()
	_dialogue_box.show()
	_show_current_node()


func advance(next_id: String = "") -> void:
	if not is_active:
		return
	var nodes: Dictionary = _dialogue_data.get("nodes", {})
	var node: Dictionary = nodes.get(_current_node_id, {})
	var target: String = next_id
	if target == "":
		target = node.get("next", "")
	if target == "" or not nodes.has(target):
		end_dialogue()
		return
	_current_node_id = target
	_show_current_node()


func end_dialogue() -> void:
	is_active = false
	_current_node_id = ""
	_dialogue_data = {}
	if _dialogue_box:
		_dialogue_box.hide()
	dialogue_ended.emit()


func _show_current_node() -> void:
	var nodes: Dictionary = _dialogue_data.get("nodes", {})
	var node: Dictionary = nodes.get(_current_node_id, {})
	if node.is_empty() or node.get("end", false):
		end_dialogue()
		return

	var start_battle: String = node.get("start_battle", "")
	if start_battle != "":
		GameState.pending_battle_enemy = start_battle
		GameState.pending_victory_flag = node.get("victory_flag", "")
		GameState.pending_monster_id = ""
		_dialogue_box.display_node(node)
		await get_tree().create_timer(1.2).timeout
		end_dialogue()
		get_tree().change_scene_to_file.bind("res://scenes/Battle.tscn").call_deferred()
		return

	var set_flag: String = node.get("set_flag", "")
	if set_flag != "":
		GameState.set_flag(set_flag)

	var filtered_node: Dictionary = node.duplicate(true)
	if filtered_node.has("choices"):
		var filtered_choices: Array = []
		for choice in filtered_node["choices"]:
			if _choice_available(choice):
				filtered_choices.append(choice)
		filtered_node["choices"] = filtered_choices

	_dialogue_box.display_node(filtered_node)


## A choice can gate itself on story flags: "requires_flag" (must be set) or
## "requires_not_flag" (must NOT be set). Absent = always available.
func _choice_available(choice: Dictionary) -> bool:
	var requires: String = choice.get("requires_flag", "")
	if requires != "" and not GameState.has_flag(requires):
		return false
	var requires_not: String = choice.get("requires_not_flag", "")
	if requires_not != "" and GameState.has_flag(requires_not):
		return false
	return true
