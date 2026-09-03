extends CharacterBody2D

## A container (chest/barrel/bottle/etc.) placed on a map via
## data/map_items/*.json — walk up, press Z, get the item, gone for good.
## See "How to add a world item" in PROGRESS.md. Physically blocks the
## player like an NPC does (same CharacterBody2D + Area2D pattern as
## npc.gd) so a container can't just be walked straight through.

@export var glyph: String = "="
@export var portrait_color: Color = Color(0.65, 0.5, 0.3)
@export var item_id: String = ""
@export var quantity: int = 1
@export var collected_flag: String = ""

@onready var visual: Label = $Visual
@onready var prompt: Label = $InteractionPrompt

var _player_in_range: bool = false


func _ready() -> void:
	visual.text = glyph
	visual.add_theme_color_override("font_color", portrait_color)
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
	if not _player_in_range or DialogueManager.is_active or Controls.is_help_open:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Z:
		prompt.hide()
		_collect()
		get_viewport().set_input_as_handled()


## Grants the item, marks this container permanently emptied (the flag
## keeps main.gd from respawning it on a future visit to this room — see
## _spawn_world_items), shows a one-line pickup announcement via the
## existing dialogue box, then removes this node.
func _collect() -> void:
	GameState.add_item(item_id, quantity)
	if collected_flag != "":
		GameState.set_flag(collected_flag)
	var item_name := ItemDB.localized_name(item_id)
	var message: String
	if quantity > 1:
		message = Localization.t("world.item_found_multi") % [quantity, item_name]
	else:
		message = Localization.t("world.item_found") % item_name
	DialogueManager.show_message(message)
	queue_free()
