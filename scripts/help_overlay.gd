extends CanvasLayer

## Autoload singleton (added after Controls). A CanvasLayer with a high
## `layer` so it draws above whatever scene is active, without any
## per-scene wiring — same reasoning as GameState/DialogueManager
## surviving scene changes. H toggles it; Esc closes it and consumes the
## event so pause doesn't also open on the same press. While open,
## Controls.is_help_open gates player movement/NPC interact/pause-menu
## input, the same way scripts already gate on DialogueManager.is_active.

@onready var panel: Control = $Panel
@onready var title_label: Label = $Panel/Box/MarginContainer/VBoxContainer/TitleLabel
@onready var body_label: Label = $Panel/Box/MarginContainer/VBoxContainer/BodyLabel
@onready var close_label: Label = $Panel/Box/MarginContainer/VBoxContainer/CloseLabel


func _ready() -> void:
	layer = 50
	panel.hide()
	Localization.locale_changed.connect(_refresh_texts)
	_refresh_texts()


func _refresh_texts() -> void:
	title_label.text = Localization.t("help.title")
	body_label.text = Localization.t("help.body")
	close_label.text = Localization.t("help.close_hint")


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	if event.keycode == KEY_H:
		_toggle()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_ESCAPE and panel.visible:
		_close()
		get_viewport().set_input_as_handled()


func _toggle() -> void:
	if panel.visible:
		_close()
	else:
		_open()


func _open() -> void:
	panel.show()
	Controls.is_help_open = true


func _close() -> void:
	panel.hide()
	Controls.is_help_open = false
