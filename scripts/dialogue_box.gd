extends Control

@onready var speaker_label: Label = $Panel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var text_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/TextLabel
@onready var choices_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ChoicesContainer
@onready var continue_indicator: Label = $Panel/MarginContainer/VBoxContainer/ContinueIndicator

var _current_choices: Array = []


func _ready() -> void:
	hide()
	DialogueManager.register_dialogue_box(self)


func display_node(node: Dictionary) -> void:
	speaker_label.text = node.get("speaker", "")
	text_label.text = node.get("text", "")
	_clear_choices()
	var choices: Array = node.get("choices", [])
	if choices.size() > 0:
		continue_indicator.hide()
		_current_choices = choices
		for choice in choices:
			var button := Button.new()
			button.text = choice.get("text", "")
			button.pressed.connect(_on_choice_pressed.bind(choice.get("next", "")))
			choices_container.add_child(button)
		choices_container.get_child(0).grab_focus()
	else:
		continue_indicator.show()
		_current_choices = []


func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()


func _on_choice_pressed(next_id: String) -> void:
	DialogueManager.advance(next_id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _current_choices.size() > 0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE or event.keycode == KEY_E:
			DialogueManager.advance()
			get_viewport().set_input_as_handled()
