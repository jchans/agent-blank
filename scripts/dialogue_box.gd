extends Control

@onready var margin_container: MarginContainer = $Panel/MarginContainer
@onready var speaker_label: Label = $Panel/MarginContainer/VBoxContainer/SpeakerLabel
@onready var text_label: RichTextLabel = $Panel/MarginContainer/VBoxContainer/TextLabel
@onready var choices_container: VBoxContainer = $Panel/MarginContainer/VBoxContainer/ChoicesContainer
@onready var continue_indicator: Label = $Panel/MarginContainer/VBoxContainer/ContinueIndicator

const SECONDS_PER_CHARACTER := 0.02
const MIN_TYPE_DURATION := 0.15

var _current_choices: Array = []
var _pending_choices: Array = []
var _typing_tween: Tween


## Design-resolution (720x480 fixed window, see project.godot) pixel
## position/width for this box, and a min/max height range. Position is
## hardcoded and applied unconditionally in _ready() (see
## _force_explicit_rect) because on the user's real hardware this Control's
## own anchor/offset properties read back as (0,1,1,1)/(0,0,0,0) -- Godot's
## PRESET_BOTTOM_WIDE with zero offsets -- from the very first line of
## _ready(), never matching whatever this scene file actually declares
## (confirmed correct in the packed/exported resource itself). Re-reading
## and reapplying those same properties (the old LayoutWorkaround approach)
## can't fix a value that's already wrong before anything runs, so this
## bypasses the anchor system entirely with a literal position instead.
## Height, unlike position, is NOT hardcoded -- see _resize_to_content --
## since different dialogue nodes have different amounts of text/choices
## and a fixed height would clip or overflow the panel background for
## longer ones (e.g. the Elder's, which has more choices than the Guard's).
## Panel/MarginContainer/VBoxContainer's own anchor_right=1/anchor_bottom=1
## fill-to-parent behavior is unaffected by the bug above -- real-hardware
## diagnostics already confirmed Panel's global rect correctly tracks
## whatever rect this root Control is given -- so it's safe to keep relying
## on that inner anchor chain and only bypass this root Control's own.
const BOX_POSITION := Vector2(20, 20)
const BOX_WIDTH := 680.0
const BOX_MIN_HEIGHT := 60.0
const BOX_MAX_HEIGHT := 440.0


func _ready() -> void:
	hide()
	DialogueManager.register_dialogue_box(self)
	_force_explicit_rect()


func _force_explicit_rect() -> void:
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	position = BOX_POSITION
	_resize_to_content()


## Grows/shrinks the box to fit its current text + choices, reading the
## content's own natural (minimum) size rather than the box's current
## (possibly stale, from the previous node) size -- so this works
## correctly regardless of call order relative to width being set.
func _resize_to_content() -> void:
	var content_height: float = margin_container.get_combined_minimum_size().y
	size = Vector2(BOX_WIDTH, clamp(content_height, BOX_MIN_HEIGHT, BOX_MAX_HEIGHT))


func display_node(node: Dictionary) -> void:
	_force_explicit_rect()
	speaker_label.text = Localization.speaker(node.get("speaker", ""))
	var full_text: String = Localization.text_for(node, "text")
	text_label.text = full_text
	text_label.visible_ratio = 0.0
	_clear_choices()
	continue_indicator.hide()
	_current_choices = []
	_pending_choices = node.get("choices", [])
	_resize_to_content()

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
	_resize_to_content()


func _clear_choices() -> void:
	for child in choices_container.get_children():
		child.queue_free()


func _on_choice_pressed(next_id: String) -> void:
	DialogueManager.advance(next_id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _current_choices.size() > 0 or Controls.is_help_open:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_Z:
			if _typing_tween and _typing_tween.is_running():
				_typing_tween.custom_step(1000.0)
			else:
				DialogueManager.advance()
			get_viewport().set_input_as_handled()
