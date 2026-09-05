extends Control

## Lives in Main.tscn's CanvasLayer. process_mode = ALWAYS so this keeps
## reading input while SceneTree.paused is true (everything else stops by
## default, since Godot's default node process_mode is PAUSABLE-equivalent).
## Three sub-panels share this one Control: the main pause panel, an
## Options panel (language switcher), and an Items panel (consumables +
## per-character equipment) — only one of the three is ever visible while
## the overall menu (this Control) is open.

const PARTY_DATA_DIR := "res://data/party/"

@onready var panel: Panel = $Panel
@onready var title_label: Label = $Panel/MarginContainer/VBoxContainer/TitleLabel
@onready var resume_button: Button = $Panel/MarginContainer/VBoxContainer/ResumeButton
@onready var save_button: Button = $Panel/MarginContainer/VBoxContainer/SaveButton
@onready var items_button: Button = $Panel/MarginContainer/VBoxContainer/ItemsButton
@onready var options_button: Button = $Panel/MarginContainer/VBoxContainer/OptionsButton
@onready var quit_to_title_button: Button = $Panel/MarginContainer/VBoxContainer/QuitToTitleButton
@onready var quit_button: Button = $Panel/MarginContainer/VBoxContainer/QuitButton
@onready var status_label: Label = $Panel/MarginContainer/VBoxContainer/StatusLabel

@onready var options_panel: Panel = $OptionsPanel
@onready var options_title_label: Label = $OptionsPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var language_label: Label = $OptionsPanel/MarginContainer/VBoxContainer/LanguageLabel
@onready var english_button: Button = $OptionsPanel/MarginContainer/VBoxContainer/EnglishButton
@onready var chinese_button: Button = $OptionsPanel/MarginContainer/VBoxContainer/ChineseButton
@onready var back_button: Button = $OptionsPanel/MarginContainer/VBoxContainer/BackButton

@onready var items_panel: Panel = $ItemsPanel
@onready var items_title_label: Label = $ItemsPanel/MarginContainer/VBoxContainer/TitleLabel
@onready var consumables_heading: Label = $ItemsPanel/MarginContainer/VBoxContainer/ConsumablesHeading
@onready var consumables_list: VBoxContainer = $ItemsPanel/MarginContainer/VBoxContainer/ConsumablesScroll/ConsumablesList
@onready var equipment_heading: Label = $ItemsPanel/MarginContainer/VBoxContainer/EquipmentHeading
@onready var equipment_list: VBoxContainer = $ItemsPanel/MarginContainer/VBoxContainer/EquipmentList
@onready var items_status_label: Label = $ItemsPanel/MarginContainer/VBoxContainer/ItemsStatusLabel
@onready var items_back_button: Button = $ItemsPanel/MarginContainer/VBoxContainer/BackButton


func _ready() -> void:
	hide()
	process_mode = Node.PROCESS_MODE_ALWAYS
	Localization.locale_changed.connect(_refresh_texts)
	_refresh_texts()
	LayoutWorkaround.force_relayout(panel)
	LayoutWorkaround.force_relayout(options_panel)
	LayoutWorkaround.force_relayout(items_panel)


## English/中文 button labels are proper nouns for the language itself, not
## translated — everything else here is.
func _refresh_texts() -> void:
	title_label.text = Localization.t("pause.title")
	resume_button.text = Localization.t("pause.resume")
	save_button.text = Localization.t("pause.save")
	items_button.text = Localization.t("pause.items")
	options_button.text = Localization.t("pause.options")
	quit_to_title_button.text = Localization.t("pause.quit_to_title")
	quit_button.text = Localization.t("pause.quit")
	options_title_label.text = Localization.t("options.title")
	language_label.text = Localization.t("options.language")
	back_button.text = Localization.t("options.back")
	items_title_label.text = Localization.t("items.title")
	consumables_heading.text = Localization.t("items.consumables_heading")
	equipment_heading.text = Localization.t("items.equipment_heading")
	items_back_button.text = Localization.t("items.back")
	if items_panel.visible:
		_refresh_items_panel()


func _unhandled_input(event: InputEvent) -> void:
	if Controls.is_help_open:
		return
	if DialogueManager.is_active and not visible:
		return
	if not (event is InputEventKey) or not event.pressed or event.echo:
		return
	if event.keycode == KEY_ESCAPE:
		if options_panel.visible:
			_on_back_button_pressed()
		elif items_panel.visible:
			_on_items_back_button_pressed()
		else:
			_toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.keycode == KEY_I and not visible:
		# A direct shortcut to Items while exploring, so checking your bag
		# doesn't require going through the full pause menu first — same
		# key as battle's own Item action, opened here via the same
		# panel-swap this file's Items button already uses.
		_open_items_directly()
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


## Saves first (same as the explicit Save button), matching this project's
## established "autosave on every meaningful transition" pattern (door
## crossings, battle end, opening this very menu). SceneTree.paused must
## be cleared before the title screen loads, or its own _unhandled_input
## (no process_mode override, unlike this menu) would never run —
## deferred per CLAUDE.md's change_scene_to_file rule, this being a
## signal callback.
func _on_quit_to_title_button_pressed() -> void:
	get_tree().paused = false
	GameState.save_game()
	hide()
	get_tree().change_scene_to_file.bind("res://scenes/TitleScreen.tscn").call_deferred()


func _on_items_button_pressed() -> void:
	panel.hide()
	items_panel.show()
	items_status_label.text = ""
	_refresh_items_panel()


## Entered via the "I" overworld shortcut (see _unhandled_input), skipping
## the main pause panel entirely. Still pauses the tree and autosaves,
## same as _pause() — this is a real pause, just landing straight on
## Items instead of Resume/Save/.... Backing out (Escape) goes to the
## main panel via the existing _on_items_back_button_pressed, same as
## backing out of Items when reached the normal way through that panel.
func _open_items_directly() -> void:
	get_tree().paused = true
	GameState.save_game()
	status_label.text = ""
	items_status_label.text = ""
	panel.hide()
	options_panel.hide()
	items_panel.show()
	show()
	_refresh_items_panel()


func _on_items_back_button_pressed() -> void:
	items_panel.hide()
	panel.show()
	resume_button.grab_focus()


func _refresh_items_panel() -> void:
	items_title_label.text = Localization.t("items.title")
	_rebuild_consumables_rows()
	_rebuild_equipment_rows()


## An item is usable outside battle only if its effect makes sense with no
## live CombatantStats/enemy around: heal/restore_rp target an ally and
## just adjust GameState.party_hp/party_rp directly (see _use_item_on).
## damage (targets an enemy) and buff_attack/buff_defense (last "the rest
## of the current battle" — see data/items/*.json's own doc comments in
## PROGRESS.md) have no meaning outside a battle, so those still show
## (for visibility of what's owned) but with no Use button.
const OVERWORLD_USABLE_EFFECTS := ["heal", "restore_rp"]

## Rebuilt from scratch every time the Items panel opens (or the locale
## changes while it's open), same pattern as _rebuild_equipment_rows.
## Each owned consumable gets one row: its name+count, then one button per
## party member to use it on immediately (no separate "choose target"
## step) for the effects in OVERWORLD_USABLE_EFFECTS — mirrors the
## equipment rows' "simplest thing that works for 3 characters" choice
## right above.
func _rebuild_consumables_rows() -> void:
	for child in consumables_list.get_children():
		child.queue_free()
	var ids: Array = GameState.inventory.keys()
	ids.sort()
	var any_shown := false
	for item_id in ids:
		if GameState.inventory.get(item_id, 0) <= 0:
			continue
		var item := ItemDB.get_item(item_id)
		if item.get("type", "") != "consumable":
			continue
		any_shown = true
		var id: String = item_id
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		consumables_list.add_child(row)

		var name_label := Label.new()
		name_label.text = "%s x%d" % [ItemDB.localized_name(id), GameState.inventory[id]]
		name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(name_label)

		if OVERWORLD_USABLE_EFFECTS.has(item.get("effect", "")):
			for member_id in _party_member_ids():
				var mid: String = member_id
				var b := Button.new()
				b.text = _party_member_name(mid)
				b.pressed.connect(_on_use_item.bind(id, mid))
				row.add_child(b)
		else:
			var note := Label.new()
			note.text = Localization.t("items.battle_only")
			note.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55, 1))
			row.add_child(note)
	if not any_shown:
		var empty_label := Label.new()
		empty_label.text = Localization.t("items.no_consumables")
		empty_label.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8, 1))
		consumables_list.add_child(empty_label)


## Loads just enough of a party member's base stats (hit_die/con_score for
## max HP, max_rp) to cap a heal/restore_rp effect the same way battle.gd
## would — equipment never affects max HP/RP, so unlike battle.gd's
## _load_party there's no need to also apply GameState.equipment here.
## Level *does* affect max HP/RP (see combatant_stats.gd's apply_level),
## so that's applied here too, same as battle.gd.
func _member_stats(member_id: String) -> CombatantStats:
	var file := FileAccess.open(PARTY_DATA_DIR + member_id + ".json", FileAccess.READ)
	if file == null:
		return CombatantStats.new()
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return CombatantStats.new()
	var stats := CombatantStats.from_dict(parsed)
	stats.apply_level(GameState.party_level.get(member_id, 1))
	return stats


## Applies a heal/restore_rp consumable directly to GameState.party_hp/
## party_rp — the overworld equivalent of battle.gd's _do_item, minus
## everything that only makes sense mid-battle (no CombatantStats/view/log
## to update, no enemy target).
func _on_use_item(item_id: String, member_id: String) -> void:
	var item := ItemDB.get_item(item_id)
	var stats := _member_stats(member_id)
	var current_hp: int = GameState.party_hp.get(member_id, stats.get_max_hp())
	var current_rp: int = GameState.party_rp.get(member_id, stats.max_rp)
	match item.get("effect", ""):
		"heal":
			var heal := maxi(Dice.roll_dice_string(item.get("amount_dice", "1d4")), 0)
			GameState.party_hp[member_id] = min(current_hp + heal, stats.get_max_hp())
		"restore_rp":
			var amount: int = item.get("amount", 1)
			GameState.party_rp[member_id] = min(current_rp + amount, stats.max_rp)
		_:
			return
	GameState.remove_item(item_id)
	items_status_label.text = Localization.t("items.used") % [ItemDB.localized_name(item_id), _party_member_name(member_id)]
	_rebuild_consumables_rows()


## Owned (inventory count > 0) equipment ids for one slot, sorted for a
## stable cycle order across button presses.
func _owned_equipment_ids(slot: String) -> Array:
	var ids: Array = []
	for item_id in GameState.inventory.keys():
		if GameState.inventory.get(item_id, 0) <= 0:
			continue
		var item := ItemDB.get_item(item_id)
		if item.get("type", "") == "equipment" and item.get("slot", "") == slot:
			ids.append(item_id)
	ids.sort()
	return ids


## Rebuilt from scratch every time the Items panel opens (or the locale
## changes while it's open) — same "clear and re-add" pattern
## action_menu.gd already uses for its own dynamically-populated boxes,
## simpler than diffing against whatever was there before.
func _rebuild_equipment_rows() -> void:
	for child in equipment_list.get_children():
		child.queue_free()
	var first_focus: Control = null
	for member_id in _party_member_ids():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		equipment_list.add_child(row)

		var name_label := Label.new()
		name_label.text = _party_member_name(member_id)
		name_label.custom_minimum_size = Vector2(60, 0)
		row.add_child(name_label)

		var weapon_btn := Button.new()
		_set_slot_button_text(weapon_btn, member_id, "weapon")
		weapon_btn.pressed.connect(_on_cycle_slot.bind(member_id, "weapon", weapon_btn))
		row.add_child(weapon_btn)

		var armor_btn := Button.new()
		_set_slot_button_text(armor_btn, member_id, "armor")
		armor_btn.pressed.connect(_on_cycle_slot.bind(member_id, "armor", armor_btn))
		row.add_child(armor_btn)

		if first_focus == null:
			first_focus = weapon_btn
	if first_focus:
		first_focus.grab_focus()
	else:
		items_back_button.grab_focus()


func _set_slot_button_text(btn: Button, member_id: String, slot: String) -> void:
	var current := GameState.equipped_item(member_id, slot)
	btn.text = ItemDB.localized_name(current) if current != "" else Localization.t("items.none")


## Cycles a slot through "" (unequip) + every owned item for that slot,
## wrapping around — simpler than a real drag/drop or list-picker UI for
## a party of three with at most a couple of items per slot at a time.
func _on_cycle_slot(member_id: String, slot: String, btn: Button) -> void:
	var options: Array = [""]
	options.append_array(_owned_equipment_ids(slot))
	var current := GameState.equipped_item(member_id, slot)
	var idx: int = options.find(current)
	idx = (idx + 1) % options.size()
	GameState.equip(member_id, slot, options[idx])
	_set_slot_button_text(btn, member_id, slot)


func _party_member_ids() -> Array:
	var ids: Array = []
	var dir := DirAccess.open(PARTY_DATA_DIR)
	if dir == null:
		return ids
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var file := FileAccess.open(PARTY_DATA_DIR + file_name, FileAccess.READ)
			if file:
				var parsed: Variant = JSON.parse_string(file.get_as_text())
				file.close()
				if typeof(parsed) == TYPE_DICTIONARY and parsed.has("id"):
					ids.append(parsed["id"])
		file_name = dir.get_next()
	dir.list_dir_end()
	ids.sort()
	return ids


func _party_member_name(member_id: String) -> String:
	var file := FileAccess.open(PARTY_DATA_DIR + member_id + ".json", FileAccess.READ)
	if file == null:
		return member_id
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return member_id
	if Localization.current_locale != Localization.DEFAULT_LOCALE and parsed.get("display_name_zh", "") != "":
		return parsed["display_name_zh"]
	return parsed.get("display_name", member_id)
