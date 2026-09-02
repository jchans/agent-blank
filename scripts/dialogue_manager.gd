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
	_dialogue_box.display_node(node)
