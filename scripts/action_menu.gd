extends Control
class_name ActionMenu

## SNES-FF-style command menu: main (Attack/Skill/Defend/Run) -> skill
## submenu -> target submenu. Async: pick_action() awaits the player.
## Ported from the KaomojiBattle prototype's scripts/ui/ActionMenu.gd.
##
## Keyboard scheme: this project's Controls autoload already adds Z to
## the built-in ui_accept action, so a focused Button's `pressed` fires on
## Z for free (same as every other Button-based screen in this project —
## dialogue choices, pause menu) with no manual handling needed here.
## X (cancel/back) and the A/S/D main-menu shortcuts have no built-in
## Button behavior, so those are still handled manually below, same as
## the reference. Run has no shortcut on purpose, so fleeing always takes
## a deliberate press.

signal choice_made(data: Dictionary)

@onready var prompt_label: RichTextLabel = $PromptLabel
@onready var main_box: HBoxContainer = $MainBox
@onready var skill_box: HBoxContainer = $SkillBox
@onready var item_box: HBoxContainer = $ItemBox
@onready var target_box: HBoxContainer = $TargetBox

var _actor: CombatantStats
var _enemies: Array[CombatantStats] = []
var _allies: Array[CombatantStats] = []
var _back: Callable = Callable()

func _ready() -> void:
	visible = false

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	match event.keycode:
		KEY_X:
			if _back.is_valid():
				_back.call()
		KEY_A:
			if main_box.visible:
				_show_target(_enemies, func(t): choice_made.emit({"type": "attack", "target": t}), _show_main.bind(_enemies, _allies))
		KEY_S:
			if main_box.visible and not _actor.skills.is_empty():
				_show_skills(_enemies, _allies)
		KEY_D:
			if main_box.visible:
				choice_made.emit({"type": "defend"})
		KEY_I:
			if main_box.visible and not _usable_items().is_empty():
				_show_items(_enemies, _allies)
		_:
			return
	get_viewport().set_input_as_handled()

func _clear_box(box: Container) -> void:
	for child in box.get_children():
		child.queue_free()

func _add_button(box: Container, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(callback)
	box.add_child(b)
	return b

## Shows the menu, waits for the player to fully choose an action, and
## returns it as {type: "attack"|"skill"|"defend"|"run", skill?: Skill, target?: CombatantStats}.
func pick_action(actor: CombatantStats, enemies: Array[CombatantStats], allies: Array[CombatantStats]) -> Dictionary:
	_actor = actor
	_enemies = enemies
	_allies = allies
	visible = true
	_show_main(enemies, allies)
	var result: Dictionary = await choice_made
	visible = false
	return result

func _show_main(enemies: Array[CombatantStats], allies: Array[CombatantStats]) -> void:
	main_box.visible = true
	skill_box.visible = false
	item_box.visible = false
	target_box.visible = false
	_back = Callable()
	prompt_label.text = "[center][b][color=#%s]%s[/color][/b] %s[/center]" % [_actor.log_color.to_html(false), _actor.localized_name(), Localization.t("battle.turn_prompt")]
	_clear_box(main_box)
	var attack_btn := _add_button(main_box, Localization.t("battle.action_attack"), func(): _show_target(enemies, func(t): choice_made.emit({"type": "attack", "target": t}), _show_main.bind(enemies, allies)))
	if not _actor.skills.is_empty():
		_add_button(main_box, Localization.t("battle.action_skill"), func(): _show_skills(enemies, allies))
	if not _usable_items().is_empty():
		_add_button(main_box, Localization.t("battle.action_item"), func(): _show_items(enemies, allies))
	_add_button(main_box, Localization.t("battle.action_defend"), func(): choice_made.emit({"type": "defend"}))
	_add_button(main_box, Localization.t("battle.action_run"), func(): choice_made.emit({"type": "run"}))
	attack_btn.grab_focus()

func _show_skills(enemies: Array[CombatantStats], allies: Array[CombatantStats]) -> void:
	main_box.visible = false
	skill_box.visible = true
	item_box.visible = false
	_back = _show_main.bind(enemies, allies)
	prompt_label.text = "[center][b]%s[/b][/center]" % Localization.t("battle.choose_skill")
	_clear_box(skill_box)
	var first_button: Button
	for s in _actor.skills:
		var skill: Skill = s
		var affordable := _actor.current_rp >= skill.rp_cost
		var b := _add_button(skill_box, "%s (RP%d)" % [skill.localized_name(), skill.rp_cost], func():
			var pool := allies if skill.targets_ally else enemies
			_show_target(pool, func(t): choice_made.emit({"type": "skill", "skill": skill, "target": t}), _show_skills.bind(enemies, allies))
		)
		b.tooltip_text = skill.localized_description()
		b.disabled = not affordable
		if first_button == null:
			first_button = b
	var back_btn := _add_button(skill_box, Localization.t("battle.action_back"), func(): _show_main(enemies, allies))
	(first_button if first_button else back_btn).grab_focus()

## Consumable item ids owned in GameState.inventory (count > 0) — the
## items usable from battle's Item menu. Equipment never appears here;
## it's assigned outside battle via the pause menu's Items screen.
func _usable_items() -> Array:
	var ids: Array = []
	for item_id in GameState.inventory.keys():
		if GameState.inventory.get(item_id, 0) <= 0:
			continue
		if ItemDB.get_item(item_id).get("type", "") == "consumable":
			ids.append(item_id)
	ids.sort()
	return ids

func _show_items(enemies: Array[CombatantStats], allies: Array[CombatantStats]) -> void:
	main_box.visible = false
	item_box.visible = true
	_back = _show_main.bind(enemies, allies)
	prompt_label.text = "[center][b]%s[/b][/center]" % Localization.t("battle.choose_item")
	_clear_box(item_box)
	var first_button: Button
	for item_id in _usable_items():
		var id: String = item_id
		var item := ItemDB.get_item(id)
		var count := GameState.item_count(id)
		var b := _add_button(item_box, "%s x%d" % [ItemDB.localized_name(id), count], func():
			match item.get("target", "ally"):
				"enemy":
					_show_target(enemies, func(t): choice_made.emit({"type": "item", "item_id": id, "target": t}), _show_items.bind(enemies, allies))
				"self":
					choice_made.emit({"type": "item", "item_id": id, "target": _actor})
				_:
					_show_target(allies, func(t): choice_made.emit({"type": "item", "item_id": id, "target": t}), _show_items.bind(enemies, allies))
		)
		b.tooltip_text = ItemDB.localized_description(id)
		if first_button == null:
			first_button = b
	var back_btn := _add_button(item_box, Localization.t("battle.action_back"), func(): _show_main(enemies, allies))
	(first_button if first_button else back_btn).grab_focus()

func _show_target(pool: Array[CombatantStats], on_pick: Callable, back_to: Callable) -> void:
	main_box.visible = false
	skill_box.visible = false
	item_box.visible = false
	target_box.visible = true
	_back = back_to
	prompt_label.text = "[center][b]%s[/b][/center]" % Localization.t("battle.choose_target")
	_clear_box(target_box)
	var first_button: Button
	for t in pool:
		var target: CombatantStats = t
		if not target.is_alive():
			continue
		var b := _add_button(target_box, target.localized_name(), func(): on_pick.call(target))
		if first_button == null:
			first_button = b
	var back_btn := _add_button(target_box, Localization.t("battle.action_back"), back_to)
	(first_button if first_button else back_btn).grab_focus()
