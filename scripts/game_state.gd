extends Node

## Autoload singleton. Tracks story flags, party battle stats, and the
## shared item system, persisted immediately to user://save.json on every
## change.

const SAVE_PATH := "user://save.json"

var flags: Dictionary = {}

## Party HP/RP, keyed by data/party/*.json's "id" field, persisting a
## party member's current HP/RP across battle encounters (see
## combatant_stats.gd's reset_for_battle() and battle.gd's _load_party()
## for why this replaced the old single-character player_hp/player_max_hp/
## player_attack fields when the battle system was ported to be
## D&D-5e-lite and party-based — see PROGRESS.md's Notes/decisions for
## that whole port). A party member with no entry here yet starts at full
## HP/RP the first time they're loaded into a battle.
var party_hp: Dictionary = {}
var party_rp: Dictionary = {}

## party_member_id -> total XP earned / current level (see
## combatant_stats.gd's apply_level/level_for_xp and battle.gd's
## _award_xp). Deliberately never surfaced in any UI — the user asked for
## leveling to happen silently, so there's no "XP: N/300" label or
## "LEVEL UP!" toast anywhere; a party member with no entry here yet is
## level 1 / 0 XP, same default apply_level(1) already produces.
var party_xp: Dictionary = {}
var party_level: Dictionary = {}

## Shared party inventory: item_id (see data/items/*.json) -> count owned.
## Consumables and equipment both live here; equipping doesn't remove an
## item from this count (see equipment below) — a picked-up sword just
## becomes available to assign to whichever party member wants it.
var inventory: Dictionary = {}
## party_member_id -> {"weapon": item_id, "armor": item_id}. Missing slot
## or missing member entry means "nothing equipped" — battle.gd applies
## these on top of a combatant's base JSON stats when a battle starts.
var equipment: Dictionary = {}

## Kept in sync from Main._process() while the overworld is loaded; written
## to save.json whenever save_game() runs (flag change, battle end, pause).
## Default matches Main.tscn's current spawn point.
var player_position: Vector2 = Vector2(300, 180)
## True once a save was actually loaded with a player_position in it —
## distinguishes "fresh game, use the scene's default spawn" from "resume
## a save, override the spawn".
var has_saved_position: bool = false

## Which data/maps/<id>.txt room the player is in. Set by Main whenever it
## loads a room (initial load and door transitions), read at startup to
## pick the room a saved game resumes into.
var current_map: String = "village"

## UI/dialogue language ("en" or "zh"). Read by Localization at startup,
## written by Localization.set_locale(). Deliberately NOT reset by
## reset_new_game() — it's a player/device preference, not story state.
var locale: String = "en"

## Set by whoever triggers a battle (e.g. DialogueManager on a "start_battle"
## node) right before changing to Battle.tscn; Battle reads it in _ready().
var pending_battle_enemy: String = ""
## Optional flag name set via set_flag() when the upcoming battle is won —
## e.g. a dialogue node's "victory_flag" field (see dialogue_manager.gd).
## Empty means no flag to set. Not persisted (transient, like the above).
var pending_victory_flag: String = ""
## Set only by a RoamingMonster's contact trigger (its synthesized "<map>_<
## index>" id, see main.gd._spawn_monsters/roaming_monster.gd) right before
## changing to Battle.tscn; every other battle trigger (dialogue, tile
## encounter) explicitly clears this to "" so a stale id from an earlier
## monster battle can't leak a defeat/flee record onto an unrelated fight.
## Not persisted (transient, like the two fields above).
var pending_monster_id: String = ""

## monster_id -> Time.get_unix_time_from_system() when it was defeated.
## Checked by main.gd._spawn_monsters to skip (re)spawning a monster for
## MONSTER_RESPAWN_SECONDS after it falls — "defeated monsters should
## disappear, and respawn after a delay" (user request). Persisted so the
## despawn survives a save/quit/reload.
var monster_defeats: Dictionary = {}
## monster_id -> Time.get_unix_time_from_system() until which that specific
## monster should stay idle instead of chasing/triggering again. Set on a
## successful Run against a RoamingMonster-triggered battle so the same
## monster doesn't immediately re-catch the player the instant Main.tscn
## reloads (user report: fleeing "succeeds" but you can't actually get
## away). Deliberately NOT persisted — it's a few-second anti-frustration
## grace, not state worth surviving a save/quit.
var monster_flee_grace: Dictionary = {}


func _ready() -> void:
	load_game()


## Resets in-memory state to a fresh game's defaults, without touching the
## save file on disk — a subsequent set_flag()/save_game() call (or the
## first pause/battle/etc.) will overwrite it. Used by the title screen's
## "New Game" so an existing save doesn't force "Continue".
func reset_new_game() -> void:
	flags = {}
	party_hp = {}
	party_rp = {}
	party_xp = {}
	party_level = {}
	inventory = {}
	equipment = {}
	monster_defeats = {}
	monster_flee_grace = {}
	player_position = Vector2(300, 180)
	has_saved_position = false
	current_map = "village"


func set_flag(flag_name: String) -> void:
	flags[flag_name] = true
	save_game()


func has_flag(flag_name: String) -> bool:
	return flags.get(flag_name, false)


func add_item(item_id: String, count: int = 1) -> void:
	inventory[item_id] = inventory.get(item_id, 0) + count
	save_game()


func remove_item(item_id: String, count: int = 1) -> void:
	var have: int = inventory.get(item_id, 0) - count
	if have <= 0:
		inventory.erase(item_id)
	else:
		inventory[item_id] = have
	save_game()


func item_count(item_id: String) -> int:
	return inventory.get(item_id, 0)


func equip(member_id: String, slot: String, item_id: String) -> void:
	if not equipment.has(member_id):
		equipment[member_id] = {}
	if item_id == "":
		equipment[member_id].erase(slot)
	else:
		equipment[member_id][slot] = item_id
	save_game()


func equipped_item(member_id: String, slot: String) -> String:
	return equipment.get(member_id, {}).get(slot, "")


func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("GameState: could not open save file for writing: %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify({
		"flags": flags,
		"party_hp": party_hp,
		"party_rp": party_rp,
		"party_xp": party_xp,
		"party_level": party_level,
		"inventory": inventory,
		"equipment": equipment,
		"monster_defeats": monster_defeats,
		"player_position": [player_position.x, player_position.y],
		"current_map": current_map,
		"locale": locale,
	}))
	file.close()


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		flags = parsed.get("flags", {})
		party_hp = parsed.get("party_hp", {})
		party_rp = parsed.get("party_rp", {})
		party_xp = parsed.get("party_xp", {})
		party_level = parsed.get("party_level", {})
		inventory = parsed.get("inventory", {})
		equipment = parsed.get("equipment", {})
		monster_defeats = parsed.get("monster_defeats", {})
		var pos: Array = parsed.get("player_position", [])
		if pos.size() == 2:
			player_position = Vector2(pos[0], pos[1])
			has_saved_position = true
		current_map = parsed.get("current_map", current_map)
		locale = parsed.get("locale", locale)
