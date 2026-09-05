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
## as the opposing combatant(s) — a single id for one enemy, or several
## ids joined with "," to load them all as simultaneous opponents (see
## main.gd._check_random_encounter, the only trigger that currently ever
## sets more than one). GameState.pending_victory_flag (if set) is applied
## on victory. Both are set by DialogueManager reading a dialogue node's
## "start_battle"/"victory_flag" fields — unchanged from before this port.

const ENEMY_DATA_DIR := "res://data/enemies/"
const PARTY_DATA_DIR := "res://data/party/"
const CombatantViewScene := preload("res://scenes/CombatantView.tscn")

@onready var panel: Panel = $UI/Panel
@onready var hint_label: Label = $UI/Panel/MarginContainer/VBoxContainer/HintLabel
@onready var enemy_row: HBoxContainer = $UI/Panel/MarginContainer/VBoxContainer/BattleRow/CombatantsColumn/EnemyRow
@onready var party_row: HBoxContainer = $UI/Panel/MarginContainer/VBoxContainer/BattleRow/CombatantsColumn/PartyRow
@onready var log_scroll: ScrollContainer = $UI/Panel/MarginContainer/VBoxContainer/BattleRow/LogScroll
@onready var battle_log: RichTextLabel = $UI/Panel/MarginContainer/VBoxContainer/BattleRow/LogScroll/LogLabel
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
	enemies = []
	for id in enemy_id.split(","):
		enemies.append(_load_enemy(id))

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

	if enemies.size() > 1:
		_log(Localization.t("battle.appears_group") % _group_description(enemies))
	else:
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
				_apply_equipment(c)
				c.apply_level(GameState.party_level.get(c.id, 1))
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


## Layers a party member's persisted gear (GameState.equipment, set via the
## pause menu's Items screen) on top of their base JSON stats. Enemies
## never have equipment, so this is only called from _load_party.
func _apply_equipment(c: CombatantStats) -> void:
	var equipped: Dictionary = GameState.equipment.get(c.id, {})
	var weapon_id: String = equipped.get("weapon", "")
	if weapon_id != "":
		var item := ItemDB.get_item(weapon_id)
		if item.get("slot", "") == "weapon":
			c.apply_weapon_equipment(item)
	var armor_id: String = equipped.get("armor", "")
	if armor_id != "":
		var item := ItemDB.get_item(armor_id)
		if item.get("slot", "") == "armor":
			c.apply_armor_equipment(item)


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
		"item":
			await _do_item(actor, choice["item_id"], choice["target"])
		"defend":
			actor.is_defending = true
			_set_state(actor, "defend")
			_log(Localization.t("battle.defends") % _name(actor))
			await _pause()
		"run":
			await _do_run(actor)
	_log_separator()
	_refresh_all()


## Seconds a RoamingMonster stays put after the player successfully Runs
## from a battle it triggered — see GameState.monster_flee_grace. Only
## relevant when GameState.pending_monster_id is set (i.e. this battle
## started from a RoamingMonster's contact, not a dialogue/tile-encounter
## battle), applied in _end_battle.
const FLEE_GRACE_SECONDS := 5.0

## Run used to always succeed instantly — user feedback: it should be a
## real agility contest, not a guaranteed escape. `actor` rolls d20+DEX
## against the (single) enemy's own d20+DEX; ties favor the party since
## it's their turn/initiative to act. A failed attempt just burns the
## turn, same shape as a Defend or Attack that misses — the battle
## continues.
func _do_run(actor: CombatantStats) -> void:
	var foes := _living(enemies)
	if foes.is_empty():
		battle_over = true
		_fled = true
		return
	var foe: CombatantStats = foes[0]
	var actor_mod := actor.get_modifier("dex")
	var foe_mod := foe.get_modifier("dex")
	var actor_roll := Dice.d20()
	var foe_roll := Dice.d20()
	var actor_total := actor_roll + actor_mod
	var foe_total := foe_roll + foe_mod
	_log(Localization.t("battle.flee_roll") % [_name(actor), actor_roll, actor_mod, actor_total, _name(foe), foe_roll, foe_mod, foe_total])
	if actor_total >= foe_total:
		_log(Localization.t("battle.flee_success") % _name(actor))
		battle_over = true
		_fled = true
	else:
		_log(Localization.t("battle.flee_failed") % _name(actor))
		await _pause()


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
		var dmg := Dice.roll_dice_string(actor.weapon_dice) + actor.get_modifier(actor.weapon_ability) + actor.equip_damage_bonus
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


## Consumes one unit of `item_id` from the shared party inventory and
## applies its effect (see data/items/*.json's "effect" field). Unlike
## Skill, an item's effect isn't an enum in code — the small set of
## effect strings below is the entire vocabulary items can use, kept
## flat since there are only five of them; a Skill-style class would be
## pure ceremony at this size.
func _do_item(actor: CombatantStats, item_id: String, target: CombatantStats) -> void:
	var item := ItemDB.get_item(item_id)
	GameState.remove_item(item_id)
	var item_name := ItemDB.localized_name(item_id)
	var item_text := _actor_text(actor, item_name)
	match item.get("effect", ""):
		"heal":
			var heal := maxi(Dice.roll_dice_string(item.get("amount_dice", "1d4")), 0)
			target.current_hp = min(target.current_hp + heal, target.get_max_hp())
			_set_state(target, "heal")
			_log(Localization.t("battle.item_heal") % [_name(actor), item_text, _name(target), heal])
		"restore_rp":
			var amount: int = item.get("amount", 1)
			target.current_rp = min(target.current_rp + amount, target.max_rp)
			_set_state(target, "heal")
			_log(Localization.t("battle.item_restore_rp") % [_name(actor), item_text, _name(target), amount])
		"damage":
			_set_state(actor, "attack_special")
			var dmg := maxi(Dice.roll_dice_string(item.get("amount_dice", "1d4")), 0)
			_log(Localization.t("battle.item_damage") % [_name(actor), item_text, _name(target)])
			_apply_damage(target, dmg, false, actor)
		"buff_attack":
			var amount: int = item.get("amount", 1)
			target.equip_attack_bonus += amount
			_log(Localization.t("battle.item_buff_attack") % [_name(actor), item_text, _name(target)])
		"buff_defense":
			var amount: int = item.get("amount", 1)
			target.equip_ac_bonus += amount
			_log(Localization.t("battle.item_buff_defense") % [_name(actor), item_text, _name(target)])
	await _pause()
	if actor.is_alive():
		_set_state(actor, "idle")


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

## Groups same-named opponents together ("Forest Wolf x2") for a
## multi-enemy encounter's opening log line — see the "appears"/
## "appears_group" branch in _ready().
func _group_description(list: Array[CombatantStats]) -> String:
	var counts: Dictionary = {}
	var order: Array = []
	for c in list:
		var n := _name_plain(c)
		if not counts.has(n):
			counts[n] = 0
			order.append(n)
		counts[n] += 1
	var parts: PackedStringArray = PackedStringArray()
	for n in order:
		if counts[n] > 1:
			parts.append("%s x%d" % [n, counts[n]])
		else:
			parts.append(n)
	return ", ".join(parts)

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


## Silent leveling (user request: no XP number or "level up" message ever
## shown — see PROGRESS.md's Leveling entry) — every defeated enemy's
## "xp" (data/enemies/*.json) is summed and given in full to every party
## member (not divided by party size the way SRD 5.1 does for a fluid
## adventuring party; this project's party is always exactly these same
## 3 people, so full-XP-each reads as normal per-kill JRPG XP instead of
## a fraction, and still uses the SRD's own level thresholds/pacing
## unchanged). Called only on victory (not flee/defeat) — a loss already
## fully heals the party for free, awarding XP for it too would be an
## unearned double reward. A member who levels up also has their current
## HP raised by the same amount their max HP just grew by, matching
## SRD 5.1's own "leveling heals you" rule rather than silently making
## them proportionally more hurt relative to a higher cap.
func _award_xp() -> void:
	var encounter_xp := 0
	for e in enemies:
		encounter_xp += e.xp
	if encounter_xp <= 0:
		return
	for c in party:
		var old_level: int = GameState.party_level.get(c.id, 1)
		var new_xp: int = GameState.party_xp.get(c.id, 0) + encounter_xp
		GameState.party_xp[c.id] = new_xp
		var new_level: int = CombatantStats.level_for_xp(new_xp)
		if new_level > old_level:
			var hp_per_level := int(c.hit_die / 2.0) + 1 + c.get_modifier("con")
			var hp_gain := hp_per_level * (new_level - old_level)
			GameState.party_hp[c.id] = GameState.party_hp.get(c.id, c.current_hp) + hp_gain
			GameState.party_level[c.id] = new_level


func _end_battle() -> void:
	action_menu.visible = false
	if _fled:
		_log(Localization.t("battle.end_fled"))
		_sync_party_to_game_state()
		# A RoamingMonster-triggered battle (see GameState.pending_monster_id)
		# gets a short grace period so the same monster doesn't immediately
		# re-catch the player the instant Main.tscn reloads — see
		# roaming_monster.gd's _is_in_flee_grace.
		if GameState.pending_monster_id != "":
			GameState.monster_flee_grace[GameState.pending_monster_id] = Time.get_unix_time_from_system() + FLEE_GRACE_SECONDS
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
		# Defeating a RoamingMonster marks it gone (main.gd._spawn_monsters
		# skips it) until MONSTER_RESPAWN_SECONDS have passed — "a defeated
		# monster should disappear, and take a while to respawn" (user
		# request).
		if GameState.pending_monster_id != "":
			GameState.monster_defeats[GameState.pending_monster_id] = Time.get_unix_time_from_system()
		for c in party:
			if c.is_alive():
				_set_state(c, "victory")
				var view := _view_for(c)
				if view:
					view.play_victory_dance()
		_log(Localization.t("battle.end_victory"))
		_sync_party_to_game_state()
		_award_xp()
	GameState.pending_monster_id = ""
	_log_separator()
	GameState.save_game()
	await get_tree().create_timer(2.0, false).timeout
	get_tree().change_scene_to_file.bind("res://scenes/Main.tscn").call_deferred()
