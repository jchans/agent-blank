extends Node

## Autoload "ItemDB" — indexes data/items/*.json by id at startup so any
## screen (battle's Use Item menu, world pickups, the pause-menu Items
## screen) can look an item up by id without re-reading disk each time.
## Same "content lives in JSON, not code" convention as NPCs/enemies/party
## (see PROGRESS.md's Notes/decisions) — adding a new item never needs a
## script change.

const ITEM_DATA_DIR := "res://data/items/"

var _items: Dictionary = {}


func _ready() -> void:
	var dir := DirAccess.open(ITEM_DATA_DIR)
	if dir == null:
		push_warning("ItemDB: could not open item data dir: %s" % ITEM_DATA_DIR)
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			_load_item_file(ITEM_DATA_DIR + file_name)
		file_name = dir.get_next()
	dir.list_dir_end()


func _load_item_file(path: String) -> void:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("ItemDB: could not open item file: %s" % path)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("id"):
		push_warning("ItemDB: invalid item file: %s" % path)
		return
	_items[parsed["id"]] = parsed


func get_item(item_id: String) -> Dictionary:
	return _items.get(item_id, {})


func has_item(item_id: String) -> bool:
	return _items.has(item_id)


func localized_name(item_id: String) -> String:
	var item := get_item(item_id)
	if item.is_empty():
		return item_id
	if Localization.current_locale != Localization.DEFAULT_LOCALE and item.get("name_zh", "") != "":
		return item["name_zh"]
	return item.get("name", item_id)


func localized_description(item_id: String) -> String:
	var item := get_item(item_id)
	if item.is_empty():
		return ""
	if Localization.current_locale != Localization.DEFAULT_LOCALE and item.get("description_zh", "") != "":
		return item["description_zh"]
	return item.get("description", "")
