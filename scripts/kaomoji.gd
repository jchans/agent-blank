extends Node

## Autoload "Kaomoji" — kaomoji glyph per battle-state key. Placeholder art
## on purpose (consistent with this project's ASCII/text-only rule — see
## CLAUDE.md), ported near-verbatim from the KaomojiBattle prototype
## (new-godot-project/scripts/autoload/Kaomoji.gd).

const STATES := {
	"idle": "(・ω・)",
	"select": "(`・ω・´)",
	"attack": "( ゝω・)ノ",
	"attack_special": "(ノ`Д´)ノ",
	"cast": "(-ω-)ノ",
	"heal": "(*´∀`)ノ",
	"defend": "(-д-)ゞ",
	"hurt": "(´；ω；`)",
	"miss": "(・_・;)",
	"dead": "(x_x)",
	"victory": "\\(^o^)/",
	"defeat": "(ノД`)",
	"flee": "(;´Д`)ノ",
}

func get_glyph(state: String) -> String:
	return STATES.get(state, STATES["idle"])
