extends Node

## Autoload singleton. Bilingual (English default, Traditional Chinese
## optional) string lookup, backed by data/locales/*.json — content lives in
## data, not code, matching how dialogue/NPC/map content already works.
## Added after GameState in project.godot's [autoload] list, so
## GameState.locale (already loaded from user://save.json) is available by
## the time _ready() runs here.

const LOCALE_DIR := "res://data/locales/"
const DEFAULT_LOCALE := "en"

signal locale_changed

var current_locale: String = DEFAULT_LOCALE

var _strings: Dictionary = {}
var _speakers: Dictionary = {}


func _ready() -> void:
	_load_locale_file(DEFAULT_LOCALE)
	_load_locale_file("zh")
	current_locale = GameState.locale


## Switches locale, persists it, and notifies every screen currently
## listening (PauseMenu/HelpOverlay) to refresh their text in place.
func set_locale(locale_id: String) -> void:
	if not _strings.has(locale_id) or locale_id == current_locale:
		return
	current_locale = locale_id
	GameState.locale = locale_id
	GameState.save_game()
	locale_changed.emit()


## UI string lookup. Falls back to English if the key is missing in the
## current locale (and to the key itself if missing there too, so a typo'd
## key is at least visible instead of silently blank).
func t(key: String) -> String:
	var current: Dictionary = _strings.get(current_locale, {})
	if current.has(key):
		return current[key]
	return _strings.get(DEFAULT_LOCALE, {}).get(key, key)


## Translated display name for a dialogue speaker (the canonical English
## name is always what's stored in dialogue JSON's "speaker" field).
func speaker(name_en: String) -> String:
	if current_locale == DEFAULT_LOCALE:
		return name_en
	return _speakers.get(current_locale, {}).get(name_en, name_en)


## Generic helper for dialogue nodes/choices: both are Dictionaries with a
## "text" key; a "<field>_zh" sibling key holds the Chinese counterpart.
## Used identically for a dialogue node's body text and a choice's option
## text.
func text_for(dict: Dictionary, field: String = "text") -> String:
	if current_locale != DEFAULT_LOCALE:
		var zh_key: String = field + "_zh"
		if dict.has(zh_key) and dict[zh_key] != "":
			return dict[zh_key]
	return dict.get(field, "")


func _load_locale_file(locale_id: String) -> void:
	var path := LOCALE_DIR + locale_id + ".json"
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Localization: could not open locale file: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Localization: invalid locale file: %s" % path)
		return
	_strings[locale_id] = parsed.get("strings", {})
	_speakers[locale_id] = parsed.get("speakers", {})
