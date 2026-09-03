extends CharacterBody2D

## An NPC's behavior is entirely data-driven: set dialogue_path to a JSON
## dialogue graph (see dialogues/*.json) and this scene handles proximity
## detection, the "!" prompt, and handing off to DialogueManager.
##
## Idle wandering (opt-in via "wanders": true in data/npcs/<name>.json —
## see "How to add a new NPC" in PROGRESS.md) is a small idle-then-walk-
## to-a-random-nearby-point loop, frozen under the same conditions
## everything else in this project already freezes under. It's opt-in
## and defaults to a small radius so an NPC can't wander into a doorway
## or another NPC's spot in a room this script has no layout knowledge
## of; the existing wall/NPC collision (this body already has a real
## CollisionShape2D — see the class-level architecture note in
## PROGRESS.md) keeps it from wandering through walls regardless.

@export_file("*.json") var dialogue_path: String = ""
@export var npc_name: String = "NPC"
@export var portrait_color: Color = Color(0.9, 0.6, 0.2)
@export var glyph: String = "N"
@export var wanders: bool = false
@export var wander_radius: float = 48.0
@export var wander_speed: float = 20.0

@onready var visual: Label = $Visual
@onready var prompt: Label = $InteractionPrompt

var _player_in_range: bool = false
var _origin: Vector2
var _wander_target: Vector2
var _wander_moving: bool = false
var _wander_timer: float = 0.0


func _ready() -> void:
	visual.text = glyph
	visual.add_theme_color_override("font_color", portrait_color)
	prompt.hide()
	_origin = position


func _physics_process(delta: float) -> void:
	if not wanders:
		return
	if DialogueManager.is_active or Controls.is_help_open:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if _wander_moving:
		var to_target := _wander_target - position
		if to_target.length() < 2.0:
			_wander_moving = false
			_wander_timer = randf_range(1.5, 3.5)
			velocity = Vector2.ZERO
		else:
			velocity = to_target.normalized() * wander_speed
	else:
		velocity = Vector2.ZERO
		_wander_timer -= delta
		if _wander_timer <= 0.0:
			_wander_target = _origin + Vector2(randf_range(-wander_radius, wander_radius), randf_range(-wander_radius, wander_radius))
			_wander_moving = true
	move_and_slide()


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
	if not _player_in_range or DialogueManager.is_active or Controls.is_help_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Z:
		if dialogue_path != "":
			prompt.hide()
			DialogueManager.start_dialogue(dialogue_path)
		get_viewport().set_input_as_handled()
