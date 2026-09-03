extends RefCounted
class_name Skill

## A freely-designed battle ability layered on SRD 5.1 math (see
## CombatantStats). Ported from the KaomojiBattle prototype's
## scripts/data/Skill.gd, but as a plain RefCounted built from a parsed
## JSON dict (via from_dict) instead of an @export Resource — this
## project stores all content as JSON, not .tres/Resource files, for easy
## hand-editing (see PROGRESS.md's Notes/decisions).

enum Kind { ATTACK_ROLL, SAVE, HEAL }

const KIND_NAMES := {
	"attack_roll": Kind.ATTACK_ROLL,
	"save": Kind.SAVE,
	"heal": Kind.HEAL,
}

var skill_name: String = ""
var skill_name_zh: String = ""
var description: String = ""
var description_zh: String = ""
var kind: Kind = Kind.ATTACK_ROLL
var ability: String = "str" ## the caster's ability used for the roll/DC
var save_ability: String = "dex" ## only used when kind == SAVE (target's save)
var damage_dice: String = "1d6"
var half_on_save: bool = true ## only used when kind == SAVE
var rp_cost: int = 0
var kaomoji_key: String = "attack_special"
var targets_ally: bool = false ## true for heal/support skills

## `field`/`field_zh` mirrors this project's dialogue-JSON localization
## convention (see Localization.text_for) — English is the canonical key,
## `_zh` is an additive Traditional Chinese sibling.
static func from_dict(data: Dictionary) -> Skill:
	var s := Skill.new()
	s.skill_name = data.get("skill_name", "")
	s.skill_name_zh = data.get("skill_name_zh", "")
	s.description = data.get("description", "")
	s.description_zh = data.get("description_zh", "")
	s.kind = KIND_NAMES.get(data.get("kind", "attack_roll"), Kind.ATTACK_ROLL)
	s.ability = data.get("ability", "str")
	s.save_ability = data.get("save_ability", "dex")
	s.damage_dice = data.get("damage_dice", "1d6")
	s.half_on_save = data.get("half_on_save", true)
	s.rp_cost = data.get("rp_cost", 0)
	s.kaomoji_key = data.get("kaomoji_key", "attack_special")
	s.targets_ally = data.get("targets_ally", false)
	return s

## Localized skill name — same field/field_zh fallback rule as
## Localization.text_for, but usable here without a Dictionary argument
## since Skill is already a typed object.
func localized_name() -> String:
	if Localization.current_locale != Localization.DEFAULT_LOCALE and skill_name_zh != "":
		return skill_name_zh
	return skill_name

func localized_description() -> String:
	if Localization.current_locale != Localization.DEFAULT_LOCALE and description_zh != "":
		return description_zh
	return description
