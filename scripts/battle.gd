extends Node2D

## Party-based, D&D-5e-lite turn-based battle: initiative order, an
## Attack/Skill/Defend/Run command menu, kaomoji battle-state art. Ported
## from the KaomojiBattle prototype (new-godot-project/scripts/combat/
## BattleManager.gd) — see PROGRESS.md's battle-system-port entry for the
## full list of decisions made porting it into this project (JSON instead
## of Resources, one enemy per encounter instead of 3v3, HP/RP persisting
## across encounters instead of resetting every battle, no separate
## restart/quit end screen).
##
## GameState.pending_battle_enemy names which data/enemies/*.json to load
## as the single opposing combatant; GameState.pending_victory_flag (if
## set) is applied on victory. Both are set by DialogueManager reading a
## dialogue node's "start_battle"/"victory_flag" fields — unchanged from
## before this port.

const ENEMY_DATA_DIR := "res://data/enemies/"
const PARTY_DATA_DIR := "res://data/party/"
const CombatantViewScene := preload("res://scenes/CombatantView.tscn")

@onready var panel: Panel = $UI/Panel
@onready var hint_label: Label = $UI/Panel/MarginContainer/VBoxContainer/HintLabel
@onready var enemy_row: HBoxContainer = $UI/Panel/MarginContainer/VBoxContainer/EnemyRow
@onready var party_row: HBoxContainer = $UI/Panel/MarginContainer/VBoxContainer/PartyRow
@onready var log_scroll: ScrollContainer = $UI/Panel/MarginContainer/VBoxContainer/LogScroll
@onready var battle_log: RichTextLabel = $UI/Panel/MarginContainer/VBoxContainer/LogScroll/LogLabel
@onready var action_menu: ActionMenu = $UI/Panel/MarginContainer/VBoxContainer/ActionMenu

var party: Array[CombatantStats] = []
var enemies: Array[CombatantStats] = []
var party_views: Dictionary = {} # CombatantStats -> CombatantView
var enemy_views: Dictionary = {} # CombatantStats -> CombatantView
var turn_order: Array[CombatantStats] = []
var battle_over := false
var _fled := false


func _ready() -> void:
	# Belt-and-suspenders against the real-hardware Control-anchor bug
	# documented at length in PROGRESS.md's dialogue-box investigation —
	# this Panel already uses default (0,0,0,0) anchors with plain
	# offsets (never reported broken), but explicitly re-asserting the
	# rect in code costs nothing and matches the established pattern for
	# any new top-level battle/dialogue UI root going forward.
	panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
	panel.position = Vector2.ZERO
	panel.size = Vector2(720, 480)

	hint_label.text = Localization.t("battle.hint")
	log_scroll.get_v_scroll_bar().changed.connect(_scroll_log_to_bottom)
	randomize()

	party = _load_party()
	var enemy_id: String = GameState.pending_battle_enemy
	if enemy_id == "":
		enemy_id = "slime"
	enemies = [_load_enemy(enemy_id)]

	for s in party:
		var view: CombatantView = CombatantViewScene.instantiate()
		party_row.add_child(view)
		view.setup(s)
		party_views[s] = view
	for s in enemies:
		var view: CombatantView = CombatantViewScene.instantiate()
		enemy_row.add_child(view)
		view.setup(s)
		enemy_views[s] = view

	_log(Localization.t("battle.appears") % _name_plain(enemies[0]))
	_log_separator()
	_roll_initiative()
	await _run_battle_loop()


## Party members persist HP/RP across encounters (GameState.party_hp/
## party_rp), unlike the KaomojiBattle prototype's reset_for_battle()-
## every-time model — see combatant_stats.gd's reset_for_battle() doc
## comment for why. A party member with no persisted entry yet (first
## battle of a save) starts at full HP/RP.
func _load_party() -> Array[CombatantStats]:
	var list: Array[CombatantStats] = []
	var dir := DirAccess.open(PARTY_DATA_DIR)
	if dir == null:
		push_warning("Battle: could not open party data dir: %s" % PARTY_DATA_DIR)
		return list
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and file_name.ends_with(".json"):
			var c := _load_combatant(PARTY_DATA_DIR + file_name)
			if c != null:
				if GameState.party_hp.has(c.id):
					c.current_hp = GameState.party_hp[c.id]
					c.current_rp = GameState.party_rp.get(c.id, c.max_rp)
					c.is_defending = false
				else:
					c.reset_for_battle()
				list.append(c)
		file_name = dir.get_next()
	dir.list_dir_end()
	list.sort_custom(func(a, b): return a.id < b.id)
	return list


func _load_enemy(enemy_id: String) -> CombatantStats:
	var c := _load_combatant(ENEMY_DATA_DIR + enemy_id + ".json")
	if c == null:
		push_warning("Battle: could not load enemy: %s" % enemy_id)
		c = CombatantStats.new()
	c.reset_for_battle()
	return c


func _load_combatant(path: String) -> CombatantStats:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("Battle: could not open combatant data file: %s" % path)
		return null
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Battle: invalid combatant data file: %s" % path)
		return null
	return CombatantStats.from_dict(parsed)


func _roll_initiative() -> void:
	var all: Array[CombatantStats] = []
	all.append_array(party)
	all.append_array(enemies)
	for c in all:
		c.roll_initiative_once()
	all.sort_custom(func(a, b): return a.current_initiative > b.current_initiative)
	turn_order = all
	var order_text := ""
	for c in turn_order:
		order_text += "%s(%d) " % [_name_plain(c), c.current_initiative]
	_log(Localization.t("battle.initiative_order") % order_text)
	_log_separator()


func _living(list: Array[CombatantStats]) -> Array[CombatantStats]:
	var out: Array[CombatantStats] = []
	for c in list:
		if c.is_alive():
			out.append(c)
	return out


func _run_battle_loop() -> void:
	while not battle_over:
		for actor in turn_order:
			if battle_over:
				break
			if not actor.is_alive():
				continue
			actor.is_defending = false
			_refresh_all()
			await _take_turn(actor)
			_check_battle_end()
	_end_battle()


func _take_turn(actor: CombatantStats) -> void:
	if actor.is_player:
		_set_state(actor, "select")
		var choice: Dictionary = await action_menu.pick_action(actor, _living(enemies), _living(party))
		await _resolve_choice(actor, choice)
	else:
		await _enemy_take_turn(actor)


func _enemy_take_turn(actor: CombatantStats) -> void:
	var targets := _living(party)
	if targets.is_empty():
		return
	var usable_skills: Array[Skill] = []
	for s in actor.skills:
		if actor.current_rp >= s.rp_cost:
			usable_skills.append(s)
	if not usable_skills.is_empty() and randf() < 0.5:
		var skill: Skill = usable_skills[randi() % usable_skills.size()]
		var target: CombatantStats = targets[randi() % targets.size()]
		await _resolve_choice(actor, {"type": "skill", "skill": skill, "target": target})
	else:
		var target: CombatantStats = targets[randi() % targets.size()]
		await _resolve_choice(actor, {"type": "attack", "target": target})


func _resolve_choice(actor: CombatantStats, choice: Dictionary) -> void:
	match choice.get("type"):
		"attack":
			await _do_attack(actor, choice["target"])
		"skill":
			await _do_skill(actor, choice["skill"], choice["target"])
		"defend":
			actor.is_defending = true
			_set_state(actor, "defend")
			_log(Localization.t("battle.defends") % _name(actor))
			await _pause()
		"run":
			_log(Localization.t("battle.flees") % _name(actor))
			battle_over = true
			_fled = true
	_log_separator()
	_refresh_all()


func _do_attack(actor: CombatantStats, target: CombatantStats) -> void:
	_set_state(actor, "attack")
	_play_lunge_toward(actor, target)
	var atk_bonus := actor.get_attack_bonus(actor.weapon_ability)
	var roll := Dice.d20()
	var total := roll + atk_bonus
	_log(Localization.t("battle.attack_roll") % [_name(actor), _name(target), _actor_text(actor, actor.localized_weapon_name()), roll, atk_bonus, total, target.get_ac()])
	if roll == 1:
		_log(Localization.t("battle.crit_miss"))
		_set_state(target, "miss")
	elif roll == 20 or total >= target.get_ac():
		var crit := roll == 20
		var dmg := Dice.roll_dice_string(actor.weapon_dice) + actor.get_modifier(actor.weapon_ability)
		if crit:
			dmg += Dice.roll_dice_string(actor.weapon_dice)
			_log(Localization.t("battle.crit_hit"))
		_apply_damage(target, max(dmg, 0), crit, actor)
	else:
		_log(Localization.t("battle.miss"))
		_set_state(target, "miss")
	await _pause()
	if actor.is_alive():
		_set_state(actor, "idle")


func _do_skill(actor: CombatantStats, skill: Skill, target: CombatantStats) -> void:
	actor.current_rp -= skill.rp_cost
	_set_state(actor, skill.kaomoji_key)
	match skill.kind:
		Skill.Kind.ATTACK_ROLL:
			_resolve_skill_attack_roll(actor, skill, target)
		Skill.Kind.SAVE:
			_resolve_skill_save(actor, skill, target)
		Skill.Kind.HEAL:
			_resolve_skill_heal(actor, skill, target)
	await _pause()
	if actor.is_alive():
		_set_state(actor, "idle")


func _resolve_skill_attack_roll(actor: CombatantStats, skill: Skill, target: CombatantStats) -> void:
	_play_lunge_toward(actor, target)
	var atk_bonus := actor.get_attack_bonus(skill.ability)
	var roll := Dice.d20()
	var total := roll + atk_bonus
	_log(Localization.t("battle.skill_attack_roll") % [_name(actor), _actor_text(actor, skill.localized_name()), _name(target), roll, atk_bonus, total, target.get_ac()])
	if roll == 1:
		_log(Localization.t("battle.crit_miss"))
		_set_state(target, "miss")
	elif roll == 20 or total >= target.get_ac():
		var crit := roll == 20
		var dmg := Dice.roll_dice_string(skill.damage_dice) + actor.get_modifier(skill.ability)
		if crit:
			dmg += Dice.roll_dice_string(skill.damage_dice)
			_log(Localization.t("battle.crit_hit"))
		_apply_damage(target, max(dmg, 0), crit, actor)
	else:
		_log(Localization.t("battle.miss"))
		_set_state(target, "miss")


func _resolve_skill_save(actor: CombatantStats, skill: Skill, target: CombatantStats) -> void:
	_play_lunge_toward(actor, target)
	var dc := actor.get_save_dc(skill.ability)
	var save_roll := Dice.d20()
	var save_mod := target.get_modifier(skill.save_ability)
	var save_total := save_roll + save_mod
	var dmg := maxi(Dice.roll_dice_string(skill.damage_dice) + actor.get_modifier(skill.ability), 0)
	var saved := save_total >= dc
	_log(Localization.t("battle.skill_save") % [_name(actor), _name(target), _actor_text(actor, skill.localized_name()), dc, _ability_label(skill.save_ability), save_roll, save_mod, save_total])
	if saved and skill.half_on_save:
		dmg = int(dmg / 2.0)
		_log(Localization.t("battle.save_half"))
	elif saved:
		dmg = 0
		_log(Localization.t("battle.save_no_effect"))
	else:
		_log(Localization.t("battle.save_failed"))
	_apply_damage(target, dmg, false, actor)


func _resolve_skill_heal(actor: CombatantStats, skill: Skill, target: CombatantStats) -> void:
	_play_lunge_toward(actor, target)
	var heal := maxi(Dice.roll_dice_string(skill.damage_dice) + actor.get_modifier(skill.ability), 0)
	target.current_hp = min(target.current_hp + heal, target.get_max_hp())
	_set_state(target, "heal")
	_log(Localization.t("battle.heal") % [_name(actor), _name(target), _actor_text(actor, skill.localized_name()), heal])


func _apply_damage(target: CombatantStats, dmg: int, crit: bool = false, actor: CombatantStats = null) -> void:
	target.current_hp = max(target.current_hp - dmg, 0)
	if dmg > 0:
		_log(Localization.t("battle.damage") % dmg)
		_set_state(target, "hurt")
		var target_view := _view_for(target)
		if target_view:
			var actor_view := _view_for(actor) if actor else null
			var away := (target_view.global_position - actor_view.global_position) if actor_view else Vector2.ZERO
			target_view.play_hit_reaction(away)
	if target.current_hp <= 0:
		_set_state(target, "dead")
		_log(Localization.t("battle.falls") % _name(target))
	_refresh_all()


## Colors a combatant's name in the log to match their kaomoji color.
func _name(c: CombatantStats) -> String:
	return "[color=#%s]%s[/color]" % [c.log_color.to_html(false), c.localized_name()]

func _name_plain(c: CombatantStats) -> String:
	return c.localized_name()

## Colors an actor-owned term (weapon/skill name) in the actor's color.
func _actor_text(actor: CombatantStats, text: String) -> String:
	return "[color=#%s]%s[/color]" % [actor.log_color.to_html(false), text]

func _ability_label(a: String) -> String:
	var en := {"str": "STR", "dex": "DEX", "con": "CON", "int": "INT", "wis": "WIS", "cha": "CHA"}
	var zh := {"str": "力量", "dex": "敏捷", "con": "體質", "int": "智力", "wis": "感知", "cha": "魅力"}
	if Localization.current_locale == Localization.DEFAULT_LOCALE:
		return en.get(a, a)
	return zh.get(a, a)

func _set_state(c: CombatantStats, state: String) -> void:
	var view := _view_for(c)
	if view:
		view.set_state(state)

func _view_for(c: CombatantStats) -> CombatantView:
	return party_views.get(c, enemy_views.get(c))

## Nudges `actor`'s kaomoji toward `target` and back — attack/cast flourish.
func _play_lunge_toward(actor: CombatantStats, target: CombatantStats) -> void:
	var actor_view := _view_for(actor)
	var target_view := _view_for(target)
	if actor_view and target_view:
		actor_view.play_lunge(target_view.global_position - actor_view.global_position)

func _refresh_all() -> void:
	for v in party_views.values():
		v.refresh()
	for v in enemy_views.values():
		v.refresh()

func _log(msg: String) -> void:
	battle_log.append_text(msg + "\n")


func _scroll_log_to_bottom() -> void:
	var vbar := log_scroll.get_v_scroll_bar()
	log_scroll.scroll_vertical = int(vbar.max_value)

const LOG_SEPARATOR := "－－－－－－－－"

## Marks the end of one actor's turn (or a narration line) so the log
## reads as distinct blocks instead of one unbroken wall of text.
func _log_separator() -> void:
	_log("[color=#9aa1b5]%s[/color]" % LOG_SEPARATOR)

func _pause(seconds: float = 1.2) -> void:
	await get_tree().create_timer(seconds, false).timeout

func _check_battle_end() -> void:
	if _living(party).is_empty() or _living(enemies).is_empty():
		battle_over = true


## Writes each living party member's current HP/RP back into GameState so
## it persists into the next encounter (see _load_party's doc comment).
func _sync_party_to_game_state() -> void:
	for c in party:
		GameState.party_hp[c.id] = c.current_hp
		GameState.party_rp[c.id] = c.current_rp


func _end_battle() -> void:
	action_menu.visible = false
	if _fled:
		_log(Localization.t("battle.end_fled"))
		_sync_party_to_game_state()
	elif _living(party).is_empty():
		for c in party:
			_set_state(c, "defeat")
		_log(Localization.t("battle.end_defeat"))
		# Loss fully heals the party and sends them back to the village —
		# this project's existing forgiving design (see the old battle.gd),
		# kept unchanged by this port.
		for c in party:
			c.reset_for_battle()
		_sync_party_to_game_state()
	else:
		if GameState.pending_victory_flag != "":
			GameState.set_flag(GameState.pending_victory_flag)
			GameState.pending_victory_flag = ""
		for c in party:
			if c.is_alive():
				_set_state(c, "victory")
				var view := _view_for(c)
				if view:
					view.play_victory_dance()
		_log(Localization.t("battle.end_victory"))
		_sync_party_to_game_state()
	_log_separator()
	GameState.save_game()
	await get_tree().create_timer(2.0, false).timeout
	get_tree().change_scene_to_file.bind("res://scenes/Main.tscn").call_deferred()
