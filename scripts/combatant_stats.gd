extends RefCounted
class_name CombatantStats

## Combat-relevant numeric state for one combatant, using D&D 5e SRD 5.1
## math: ability modifiers, proficiency bonus, AC, d20 attack rolls, save
## DCs. Ported from the KaomojiBattle prototype's scripts/data/
## CombatantStats.gd, but as a plain RefCounted built from a parsed JSON
## dict (via from_dict) instead of an @export Resource — this project
## stores all content (party/enemy stat blocks included) as JSON, not
## .tres/Resource files, for easy hand-editing without the Godot editor
## (see PROGRESS.md's Notes/decisions).

var id: String = ""
var display_name: String = "???"
var display_name_zh: String = ""
var char_class: String = ""
var char_class_zh: String = ""
var is_player: bool = true
var log_color: Color = Color.WHITE ## used both for the kaomoji name label and log highlighting

## Party-only leveling (see PROGRESS.md's Leveling entry). Enemies never
## level — they're built fresh each battle and reset_for_battle() is the
## only thing touched — so level stays at its default of 1 for them,
## which is exactly the "no bonus" baseline apply_level(1) would also
## produce; enemies simply never call apply_level at all.
var level: int = 1
## Which ability score benefits from the level-4/level-8 ASI bump (see
## apply_level) — usually the class's spellcasting/attack stat. Defaults
## to weapon_ability so a party member JSON that doesn't set this
## explicitly still gets a sensible growth stat.
var primary_ability: String = ""
## XP this combatant is worth when defeated (enemies only — see
## data/enemies/*.json's "xp" field and battle.gd's _award_xp).
var xp: int = 0

## Optional item drop on defeat (enemies only — see data/enemies/*.json's
## "loot" field, {"item_id": ..., "chance": 0.0-1.0}, and battle.gd's
## _award_loot). Empty id means "never drops" — most enemies have no
## "loot" field at all and get these defaults.
var loot_item_id: String = ""
var loot_chance: float = 0.0

var str_score: int = 10
var dex_score: int = 10
var con_score: int = 10
var int_score: int = 10
var wis_score: int = 10
var cha_score: int = 10

var hit_die: int = 8
var max_hp_override: int = -1 ## use to match a fixed monster HP instead of rolling from hit_die
var armor_bonus: int = 0

var weapon_name: String = ""
var weapon_name_zh: String = ""
var weapon_symbol: String = "" ## single-glyph weapon icon shown next to the combatant's name
var weapon_dice: String = "1d4"
var weapon_ability: String = "str"

var max_rp: int = 0
var skills: Array[Skill] = []

var current_hp: int = 0
var current_rp: int = 0
var is_defending: bool = false
var current_initiative: int = 0

## Additive bonuses layered on top of the base JSON stats above by
## apply_weapon_equipment/apply_armor_equipment (persisted gear, see
## GameState.equipment) and by consumable buff items in battle (see
## battle.gd's _do_item) — both use the same fields since a
## CombatantStats instance only ever lives for one battle (rebuilt fresh
## from JSON + GameState.equipment each time in battle.gd's _load_party),
## so there's nothing to reset: an item buff naturally "expires" because
## the object it modified is thrown away at the end of the encounter.
var equip_attack_bonus: int = 0
var equip_damage_bonus: int = 0
var equip_ac_bonus: int = 0

## Ability-score arrays use the standard 6-key shorthand (str/dex/con/int/
## wis/cha) throughout this system, matching the SRD's own abbreviations.
static func from_dict(data: Dictionary) -> CombatantStats:
	var c := CombatantStats.new()
	c.id = data.get("id", "")
	c.display_name = data.get("display_name", "???")
	c.display_name_zh = data.get("display_name_zh", "")
	c.char_class = data.get("char_class", "")
	c.char_class_zh = data.get("char_class_zh", "")
	c.is_player = data.get("is_player", true)
	var color_arr: Array = data.get("log_color", [1, 1, 1, 1])
	if color_arr.size() >= 3:
		c.log_color = Color(color_arr[0], color_arr[1], color_arr[2], color_arr[3] if color_arr.size() > 3 else 1.0)
	c.str_score = data.get("str_score", 10)
	c.dex_score = data.get("dex_score", 10)
	c.con_score = data.get("con_score", 10)
	c.int_score = data.get("int_score", 10)
	c.wis_score = data.get("wis_score", 10)
	c.cha_score = data.get("cha_score", 10)
	c.hit_die = data.get("hit_die", 8)
	c.max_hp_override = data.get("max_hp_override", -1)
	c.armor_bonus = data.get("armor_bonus", 0)
	c.weapon_name = data.get("weapon_name", "")
	c.weapon_name_zh = data.get("weapon_name_zh", "")
	c.weapon_symbol = data.get("weapon_symbol", "")
	c.weapon_dice = data.get("weapon_dice", "1d4")
	c.weapon_ability = data.get("weapon_ability", "str")
	c.max_rp = data.get("max_rp", 0)
	c.primary_ability = data.get("primary_ability", c.weapon_ability)
	c.xp = data.get("xp", 0)
	var loot: Dictionary = data.get("loot", {})
	c.loot_item_id = loot.get("item_id", "")
	c.loot_chance = loot.get("chance", 0.0)
	var skills_data: Array = data.get("skills", [])
	for skill_dict in skills_data:
		c.skills.append(Skill.from_dict(skill_dict))
	return c

func localized_name() -> String:
	if Localization.current_locale != Localization.DEFAULT_LOCALE and display_name_zh != "":
		return display_name_zh
	return display_name

func localized_class() -> String:
	if Localization.current_locale != Localization.DEFAULT_LOCALE and char_class_zh != "":
		return char_class_zh
	return char_class

func localized_weapon_name() -> String:
	if Localization.current_locale != Localization.DEFAULT_LOCALE and weapon_name_zh != "":
		return weapon_name_zh
	return weapon_name

static func modifier(score: int) -> int:
	return int(floor((score - 10) / 2.0))

func get_ability_score(ability: String) -> int:
	match ability:
		"str": return str_score
		"dex": return dex_score
		"con": return con_score
		"int": return int_score
		"wis": return wis_score
		"cha": return cha_score
		_: return 10

func get_modifier(ability: String) -> int:
	return modifier(get_ability_score(ability))

## SRD 5.1's own proficiency-by-level progression (+2 at 1-4, +3 at 5-8,
## +4 at 9-12 — matches exactly across this game's 1-10 level cap, see
## PROGRESS.md's Leveling entry). Now that `level` is real (see
## apply_level), this needed no change beyond swapping the hardcoded `2`
## for the formula this comment already promised.
func get_proficiency_bonus() -> int:
	return 2 + int((level - 1) / 4.0)

func get_max_hp() -> int:
	if max_hp_override >= 0:
		return max_hp_override
	return hit_die + get_modifier("con") + level_hp_bonus()

## SRD 5.1's "fixed" (average, not rolled) HP-per-level rule: each level
## past 1st grants floor(hit_die/2)+1 plus the current CON modifier.
## Deliberately not additive/stateful — recomputed fresh from `level`
## every time, since a CombatantStats instance is already rebuilt from
## scratch each battle (see the equip_* fields' doc comment above for why
## that pattern is safe here too).
func level_hp_bonus() -> int:
	if level <= 1:
		return 0
	return (level - 1) * (int(hit_die / 2.0) + 1 + get_modifier("con"))

func get_attack_bonus(ability: String) -> int:
	return get_modifier(ability) + get_proficiency_bonus() + equip_attack_bonus

func get_save_dc(ability: String) -> int:
	return 8 + get_proficiency_bonus() + get_modifier(ability)

func get_ac() -> int:
	var ac := 10 + get_modifier("dex") + armor_bonus + equip_ac_bonus
	return ac + (4 if is_defending else 0)

## Mutates this combatant's weapon fields directly (rather than layering
## on override fields) since a CombatantStats instance is already rebuilt
## from scratch every battle — see the equip_* fields' doc comment above.
## `item` is a parsed data/items/*.json dict with "slot": "weapon".
func apply_weapon_equipment(item: Dictionary) -> void:
	weapon_name = item.get("weapon_name", weapon_name)
	weapon_name_zh = item.get("weapon_name_zh", weapon_name_zh)
	weapon_symbol = item.get("weapon_symbol", weapon_symbol)
	if item.has("weapon_dice"):
		weapon_dice = item["weapon_dice"]
	equip_attack_bonus += item.get("attack_bonus", 0)
	equip_damage_bonus += item.get("damage_bonus", 0)

## `item` is a parsed data/items/*.json dict with "slot": "armor".
func apply_armor_equipment(item: Dictionary) -> void:
	equip_ac_bonus += item.get("ac_bonus", 0)

func roll_initiative_once() -> void:
	current_initiative = Dice.d20() + get_modifier("dex")

func is_alive() -> bool:
	return current_hp > 0

## Full reset (used for a brand-new game, or after a defeat — see
## battle.gd/GameState). Battles in between draw current_hp/current_rp
## from GameState's persisted party_hp/party_rp instead of resetting to
## full every time, so damage carries between encounters — a deliberate
## difference from the KaomojiBattle prototype (a single-battle
## validation tool that always starts fresh) chosen to keep this
## project's existing "loss fully heals you, otherwise HP persists"
## design (see PROGRESS.md's Notes/decisions).
func reset_for_battle() -> void:
	current_hp = get_max_hp()
	current_rp = max_rp
	is_defending = false


## SRD 5.1's own level-1-through-10 cumulative XP thresholds (levels
## 11-20 omitted — this game caps at 10, see PROGRESS.md's Leveling entry
## for why: raising the cap later is just extending this array).
const XP_THRESHOLDS := [0, 300, 900, 2700, 6500, 14000, 23000, 34000, 48000, 64000]
const MAX_LEVEL := 10

static func level_for_xp(total_xp: int) -> int:
	var lvl := 1
	for i in range(XP_THRESHOLDS.size()):
		if total_xp >= XP_THRESHOLDS[i]:
			lvl = i + 1
	return lvl

## Applies this combatant's current level as a deterministic function of
## `new_level` alone (not an incremental mutation — see level_hp_bonus's
## doc comment on why that's safe/correct given a fresh instance every
## battle): the SRD 5.1 ASI bump (+1 to `primary_ability` at level 4, +1
## more at level 8) and RP growth (+1 max_rp every 3 levels) are both
## applied here, and skills whose "unlock_level" hasn't been reached yet
## are filtered out of `skills` entirely (so they never show up in the
## Skill menu or get picked by an enemy AI). Called once per fresh
## CombatantStats, right after from_dict/equipment (see battle.gd's
## _load_party and pause_menu.gd's _member_stats).
func apply_level(new_level: int) -> void:
	level = clampi(new_level, 1, MAX_LEVEL)
	var asi := 0
	if level >= 4:
		asi += 1
	if level >= 8:
		asi += 1
	if asi > 0:
		match primary_ability:
			"str": str_score += asi
			"dex": dex_score += asi
			"con": con_score += asi
			"int": int_score += asi
			"wis": wis_score += asi
			"cha": cha_score += asi
	max_rp += int(level / 3.0)
	var unlocked: Array[Skill] = []
	for s in skills:
		if s.unlock_level <= level:
			unlocked.append(s)
	skills = unlocked
