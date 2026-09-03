extends Node

## Autoload "Dice" — shared dice-rolling utilities for the battle system's
## D&D 5e SRD-style math. Ported near-verbatim from the KaomojiBattle
## prototype (new-godot-project/scripts/autoload/Dice.gd) — see
## PROGRESS.md's battle-system-port entry for context.

func d20() -> int:
	return randi_range(1, 20)

func roll(count: int, sides: int) -> int:
	var total := 0
	for i in count:
		total += randi_range(1, sides)
	return total

## Parses strings like "1d8", "2d6+2", "1d10-1" and rolls them.
func roll_dice_string(dice: String) -> int:
	var expr := dice.strip_edges()
	var modifier := 0
	var dice_part := expr
	var plus_index := expr.find("+")
	var minus_index := expr.find("-")
	if plus_index > 0:
		dice_part = expr.substr(0, plus_index)
		modifier = int(expr.substr(plus_index + 1))
	elif minus_index > 0:
		dice_part = expr.substr(0, minus_index)
		modifier = -int(expr.substr(minus_index + 1))
	var xd := dice_part.split("d")
	var count := int(xd[0])
	var sides := int(xd[1])
	return roll(count, sides) + modifier
