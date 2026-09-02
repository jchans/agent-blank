extends CharacterBody2D

## An NPC's behavior is entirely data-driven: set dialogue_path to a JSON
## dialogue graph (see dialogues/*.json) and this scene handles proximity
## detection, the "!" prompt, and handing off to DialogueManager.

@export_file("*.json") var dialogue_path: String = ""
@export var npc_name: String = "NPC"
@export var portrait_color: Color = Color(0.9, 0.6, 0.2)

@onready var visual: ColorRect = $Visual
@onready var prompt: Label = $InteractionPrompt

var _player_in_range: bool = false


func _ready() -> void:
	visual.color = portrait_color
	prompt.hide()


func _on_interaction_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = true
		if not DialogueManager.is_active:
			prompt.show()


func _on_interaction_area_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_in_range = false
		prompt.hide()


func _unhandled_input(event: InputEvent) -> void:
	if not _player_in_range or DialogueManager.is_active:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_E:
		if dialogue_path != "":
			prompt.hide()
			DialogueManager.start_dialogue(dialogue_path)
		get_viewport().set_input_as_handled()
