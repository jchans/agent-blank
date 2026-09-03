extends CharacterBody2D

## A monster that idles until the player comes within chase_range, then
## actively pursues and forces a battle (data/enemies/<enemy_id>.json) on
## contact — the "multiple monsters chase the player" encounter type (see
## PROGRESS.md), distinct from Sunken Grove's tall-grass random-encounter
## tiles (see main.gd's _check_random_encounter). Placed via
## data/maps/<id>.monsters.json, spawned by main.gd the same data-file-
## per-object convention as NPCs/world items.

@export var glyph: String = "M"
@export var monster_color: Color = Color(0.8, 0.2, 0.2)
@export var enemy_id: String = "slime"
@export var speed: float = 70.0
@export var chase_range: float = 140.0

## Synthesized per-instance id ("<map>_<index in monsters.json>", set by
## main.gd._spawn_monsters) — identifies this monster for
## GameState.monster_defeats (despawn-then-respawn on defeat) and
## GameState.monster_flee_grace (a short pause after the player
## successfully Runs from it, so it doesn't immediately re-catch them the
## instant the room reloads). Empty only if this scene is ever instanced
## outside that spawner, in which case both mechanisms are simply inert.
var monster_id: String = ""

@onready var visual: Label = $Visual

var _player: Node2D = null
var _triggered := false


func _ready() -> void:
	visual.text = glyph
	visual.add_theme_color_override("font_color", monster_color)
	var players := get_tree().get_nodes_in_group("player")
	if not players.is_empty():
		_player = players[0]


func _is_in_flee_grace() -> bool:
	var grace_until: float = GameState.monster_flee_grace.get(monster_id, 0.0)
	return grace_until > 0.0 and Time.get_unix_time_from_system() < grace_until


func _physics_process(_delta: float) -> void:
	if _triggered or _player == null or DialogueManager.is_active or Controls.is_help_open or _is_in_flee_grace():
		velocity = Vector2.ZERO
		move_and_slide()
		return
	var to_player := _player.global_position - global_position
	velocity = to_player.normalized() * speed if to_player.length() <= chase_range else Vector2.ZERO
	move_and_slide()


## ContactArea's radius is deliberately a little larger than this body's
## own CollisionShape2D, so the trigger fires as the two bodies meet
## rather than depending on them fully overlapping (which solid-vs-solid
## collision would prevent — see the scene file's radius comment).
func _on_contact_area_body_entered(body: Node2D) -> void:
	if _triggered or not body.is_in_group("player") or _is_in_flee_grace():
		return
	_triggered = true
	GameState.pending_battle_enemy = enemy_id
	GameState.pending_victory_flag = ""
	GameState.pending_monster_id = monster_id
	GameState.player_position = body.position
	GameState.save_game()
	get_tree().change_scene_to_file.bind("res://scenes/Battle.tscn").call_deferred()
