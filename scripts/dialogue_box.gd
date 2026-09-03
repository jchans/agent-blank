extends Control

@onready var speaker_label: Label = $Panel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var text_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/TextLabel
@onready var choices_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ChoicesContainer
@onready var continue_indicator: Label = $Panel/MarginContainer/VBoxContainer/ContinueIndicator

const SECONDS_PER_CHARACTER := 0.02
const MIN_TYPE_DURATION := 0.15

var _current_choices: Array = []
var _pending_choices: Array = []
var _typing_tween: Tween


func _ready() -> void:
	hide()
	DialogueManager.register_dialogue_box(self)
	print("PANEL_DEBUG[before_fix] dialoguebox_size=", size, " dialoguebox_position=", position)
	LayoutWorkaround.force_relayout(self)
	print("PANEL_DEBUG[after_fix] dialoguebox_size=", size, " dialoguebox_position=", position)


func display_node(node: Dictionary) -> void:
	speaker_label.text = Localization.speaker(node.get("speaker", ""))
	var full_text: String = Localization.text_for(node, "text")
	text_label.text = full_text
	text_label.visible_ratio = 0.0
	_clear_choices()
	continue_indicator.hide()
	_current_choices = []
	_pending_choices = node.get("choices", [])

	if _typing_tween:
		_typing_tween.kill()

	if full_text == "":
		text_label.visible_ratio = 1.0
		_reveal_choices_or_continue()
		return

	var duration: float = max(MIN_TYPE_DURATION, full_text.length() * SECONDS_PER_CHARACTER)
	_typing_tween = create_tween()
	_typing_tween.tween_property(text_label, "visible_ratio", 1.0, duration)
	_typing_tween.finished.connect(_reveal_choices_or_continue)


func _reveal_choices_or_continue() -> void:
	if _pending_choices.size() > 0:
		_current_choices = _pending_choices
		for choice in _pending_choices:
			var button := Button.new()
			button.text = Localization.text_for(choice, "text")
			button.pressed.connect(_on_choice_pressed.bind(choice.get("next", "")))
			choices_container.add_child(button)
		choices_container.get_child(0).grab_focus()
	else:
		continue_indicator.text = Localization.t("dialogue.continue")
		continue_indicator.show()


func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()


func _on_choice_pressed(next_id: String) -> void:
	DialogueManager.advance(next_id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _current_choices.size() > 0:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			if _typing_tween and _typing_tween.is_running():
				_typing_tween.custom_step(1000.0)
			else:
				DialogueManager.advance()
			get_viewport().set_input_as_handled()
