class_name LayoutWorkaround
extends RefCounted

## Workaround for a real-hardware bug (confirmed via on-device console
## diagnostics, 2026-09-03): on the user's Windows/NVIDIA machine, an
## anchored Control's rect sometimes stays at its degenerate all-offsets-
## zero state (e.g. a Control anchored bottom-wide winds up zero-height,
## pinned to the very bottom edge) instead of resolving with its actual
## offset_* values, even after the node is fully ready and visible. This
## does not reproduce in the editor or under WSLg locally. Re-invoking
## each side's own anchor+offset setter forces Godot's normal update path
## to recompute the rect from scratch, which is a much smaller, safer fix
## than replacing the anchor system with manual position/size math.
static func force_relayout(control: Control) -> void:
	control.set_anchor_and_offset(SIDE_LEFT, control.anchor_left, control.offset_left)
	control.set_anchor_and_offset(SIDE_TOP, control.anchor_top, control.offset_top)
	control.set_anchor_and_offset(SIDE_RIGHT, control.anchor_right, control.offset_right)
	control.set_anchor_and_offset(SIDE_BOTTOM, control.anchor_bottom, control.offset_bottom)
