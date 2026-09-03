extends Control
class_name CombatantView

## Visual representation of one combatant in battle: a kaomoji glyph +
## name + HP/RP. Ported from the KaomojiBattle prototype's
## scripts/ui/CombatantView.gd, sized down to fit this project's fixed
## 720x480 window (KaomojiBattle's own window is 1152x648) and using
## Localization/CombatantStats' bilingual fields instead of a Resource's
## raw display_name.

@onready var vbox: VBoxContainer = $VBox
@onready var kaomoji_label: Label = $VBox/KaomojiLabel
@onready var name_label: Label = $VBox/NameLabel
@onready var hp_label: Label = $VBox/HPLabel
@onready var rp_label: Label = $VBox/RPLabel

var stats: CombatantStats
var _base_pos: Vector2
var _pos_tween: Tween

func _ready() -> void:
	_base_pos = vbox.position

func setup(s: CombatantStats) -> void:
	stats = s
	name_label.text = "%s【%s】" % [s.localized_name(), s.weapon_symbol]
	name_label.add_theme_color_override("font_color", s.log_color)
	name_label.tooltip_text = s.localized_weapon_name()
	kaomoji_label.add_theme_color_override("font_color", s.log_color)
	set_state("idle")
	refresh()

func set_state(state_key: String) -> void:
	kaomoji_label.text = Kaomoji.get_glyph(state_key)

func refresh() -> void:
	if stats == null:
		return
	hp_label.text = "HP %d/%d" % [max(stats.current_hp, 0), stats.get_max_hp()]
	if stats.max_rp > 0:
		rp_label.text = "RP %d/%d" % [stats.current_rp, stats.max_rp]
		rp_label.visible = true
	else:
		rp_label.visible = false
	modulate = Color(1, 1, 1, 1) if stats.is_alive() else Color(0.5, 0.5, 0.5, 0.6)

const LUNGE_LEG_DURATION := 0.12
const LUNGE_DURATION := LUNGE_LEG_DURATION * 2.0

## Nudges the kaomoji toward `direction` and back — the attack/cast lunge.
func play_lunge(direction: Vector2) -> void:
	if direction.length() < 0.001:
		return
	var offset := direction.normalized() * 16.0
	_restart_pos_tween()
	_pos_tween.tween_property(vbox, "position", _base_pos + offset, LUNGE_LEG_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pos_tween.tween_property(vbox, "position", _base_pos, LUNGE_LEG_DURATION).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Recoils away from the attacker — the hit-reaction "impact" beat. Waits
## for the attacker's own lunge to finish landing first, so the knockback
## reads as a reaction to the hit rather than happening at the same time.
## `away_direction` unset/zero-length (no known attacker) falls back to an
## in-place rattle.
func play_hit_reaction(away_direction: Vector2 = Vector2.ZERO) -> void:
	await get_tree().create_timer(LUNGE_DURATION, false).timeout
	_restart_pos_tween()
	if away_direction.length() > 0.001:
		var knock := away_direction.normalized() * 10.0
		_pos_tween.tween_property(vbox, "position", _base_pos + knock, 0.06).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		_pos_tween.tween_property(vbox, "position", _base_pos, 0.14).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	else:
		var amp := 6.0
		for i in range(4):
			var dx := amp if i % 2 == 0 else -amp
			_pos_tween.tween_property(vbox, "position", _base_pos + Vector2(dx, 0), 0.03)
			amp *= 0.55
		_pos_tween.tween_property(vbox, "position", _base_pos, 0.03)

## Loops a little hop-left/hop-right bounce — the post-victory celebration.
func play_victory_dance() -> void:
	_restart_pos_tween()
	_pos_tween.set_loops()
	_pos_tween.tween_property(vbox, "position", _base_pos + Vector2(-4, -10), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pos_tween.tween_property(vbox, "position", _base_pos, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	_pos_tween.tween_property(vbox, "position", _base_pos + Vector2(4, -10), 0.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	_pos_tween.tween_property(vbox, "position", _base_pos, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)

## Stops whatever position tween is running (lunge/shake/dance) and snaps
## back to rest — used once the victory hold is over.
func stop_position_tween() -> void:
	if _pos_tween and _pos_tween.is_valid():
		_pos_tween.kill()
	vbox.position = _base_pos

func _restart_pos_tween() -> void:
	if _pos_tween and _pos_tween.is_valid():
		_pos_tween.kill()
	vbox.position = _base_pos
	_pos_tween = create_tween()
