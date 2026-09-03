extends Control

## Lives in Main.tscn's CanvasLayer. process_mode = ALWAYS so this keeps
## reading input while SceneTree.paused is true (everything else stops by
## default, since Godot's default node process_mode is PAUSABLE-equivalent).
## Two sub-panels share this one Control: the main pause panel and an
## Options panel (language switcher) reached from it — only one of the two
## is ever visible while the overall menu (this Control) is open.

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var resume_button: Button = $Panel/MarginContainer/VBoxContainer/ResumeButton
@onready var save_button: Button = $Panel/MarginContainer/VBoxContainer/SaveButton
@onready var options_button: Button = $Panel/MarginContainer/VBoxContainer/OptionsButton
@onready var quit_button: Button = $Panel/MarginContainer/VBoxContainer/QuitButton
@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel

@onready var options_panel: Panel = $OptionsPanel
@onready var options_title_label: Label = $OptionsPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var language_label: Label = $OptionsPanel/MarginContainer/VBoxContainer/LanguageLabel
@onready var english_button: Button = $OptionsPanel/MarginContainer/VBoxContainer/EnglishButton
@onready var chinese_button: Button = $OptionsPanel/MarginContainer/VBoxContainer/ChineseButton
@onready var back_button: Button = $OptionsPanel/MarginContainer/VBoxContainer/BackButton


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	Localization.locale_changed.connect(_refresh_texts)
	_refresh_texts()
	LayoutWorkaround.force_relayout(panel)
	LayoutWorkaround.force_relayout(options_panel)


## English/中文 button labels are proper nouns for the language itself, not
## translated — everything else here is.
func _refresh_texts() -> void:
	title_label.text = Localization.t("pause.title")
	resume_button.text = Localization.t("pause.resume")
	save_button.text = Localization.t("pause.save")
	options_button.text = Localization.t("pause.options")
	quit_button.text = Localization.t("pause.quit")
	options_title_label.text = Localization.t("options.title")
	language_label.text = Localization.t("options.language")
	back_button.text = Localization.t("options.back")


func _unhandled_input(event: InputEvent) -> void:
	if Controls.is_help_open:
		return
	if DialogueManager.is_active and not visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if options_panel.visible:
			_on_back_button_pressed()
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()


func _toggle_pause() -> void:
	if visible:
		_resume()
	else:
		_pause()


func _pause() -> void:
	get_tree().paused = true
	GameState.save_game()
	status_label.text = ""
	options_panel.hide()
	panel.show()
	show()
	resume_button.grab_focus()


func _resume() -> void:
	get_tree().paused = false
	hide()


func _on_resume_button_pressed() -> void:
	_resume()


func _on_save_button_pressed() -> void:
	GameState.save_game()
	status_label.text = Localization.t("pause.saved")


func _on_options_button_pressed() -> void:
	panel.hide()
	options_panel.show()
	english_button.grab_focus()


func _on_back_button_pressed() -> void:
	options_panel.hide()
	panel.show()
	resume_button.grab_focus()


func _on_english_button_pressed() -> void:
	Localization.set_locale("en")


func _on_chinese_button_pressed() -> void:
	Localization.set_locale("zh")


func _on_quit_button_pressed() -> void:
	get_tree().quit()
