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
	_print_panel_diagnostics("ready_immediate")
	call_deferred("_print_panel_diagnostics", "ready_deferred")


func _print_panel_diagnostics(tag: String) -> void:
	var panel := $Panel as Panel
	var sb := panel.get_theme_stylebox("panel")
	print("PANEL_DEBUG[", tag, "] stylebox_class=", sb.get_class() if sb else "null")
	if sb is StyleBoxFlat:
		var flat := sb as StyleBoxFlat
		print("PANEL_DEBUG[", tag, "] bg_color=", flat.bg_color)
		print("PANEL_DEBUG[", tag, "] corner_radius_tl=", flat.corner_radius_top_left)
		print("PANEL_DEBUG[", tag, "] anti_aliasing=", flat.anti_aliasing)
		print("PANEL_DEBUG[", tag, "] border_width_left=", flat.border_width_left)
	print("PANEL_DEBUG[", tag, "] panel_size=", panel.size, " panel_position=", panel.position)
	print("PANEL_DEBUG[", tag, "] panel_visible=", panel.visible, " panel_modulate=", panel.modulate, " panel_self_modulate=", panel.self_modulate)
	print("PANEL_DEBUG[", tag, "] dialoguebox_size=", size, " dialoguebox_position=", position, " dialoguebox_visible=", visible)
	print("PANEL_DEBUG[", tag, "] viewport_size=", get_viewport_rect().size)
	print("PANEL_DEBUG[", tag, "] window_size=", DisplayServer.window_get_size())
	print("PANEL_DEBUG[", tag, "] screen_dpi_scale=", DisplayServer.screen_get_scale())
	print("PANEL_DEBUG[", tag, "] rendering_method=", ProjectSettings.get_setting("rendering/renderer/rendering_method"))
	print("PANEL_DEBUG[", tag, "] video_adapter_name=", RenderingServer.get_video_adapter_name())
	print("PANEL_DEBUG[", tag, "] video_adapter_vendor=", RenderingServer.get_video_adapter_vendor())
	print("PANEL_DEBUG[", tag, "] video_adapter_api=", RenderingServer.get_video_adapter_api_version())
	print("PANEL_DEBUG[", tag, "] project_theme_setting=", ProjectSettings.get_setting("gui/theme/custom", "UNSET"))


func display_node(node: Dictionary) -> void:
	call_deferred("_print_panel_diagnostics", "display_node")
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
