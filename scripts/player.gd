extends CharacterBody2D

@export var speed: float = 150.0

## Frostbite Hollow's ice tiles (glyph "^" in main.gd's TILE_COLORS/room
## data): steering still works freely on ice, but letting go of the
## arrow keys does NOT stop you — you keep gliding in whatever direction
## you last pressed until you steer elsewhere, leave the ice, or hit a
## wall. Deliberately simpler than a "committed slide direction you can't
## change until fully stopped" (classic Pokémon-style ice puzzle) — that
## version risks a genuine softlock if a room design ever leaves a wall
## directly ahead with ice underfoot and no escape heading queued; this
## version can always be steered out immediately, so a bad room layout
## just feels clumsy rather than ever trapping the player. TILE_SIZE
## (24.0) is duplicated from main.gd rather than shared — it's a stable,
## foundational constant unlikely to change, and pulling in a real
## dependency for one number isn't worth it.
const TILE_SIZE := 24.0
const ICE_GLYPH := "^"

var _last_direction := Vector2.DOWN


func _ready() -> void:
	add_to_group("player")


func _physics_process(_delta: float) -> void:
	if DialogueManager.is_active or Controls.is_help_open:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var input_vector := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT):
		input_vector.x -= 1
	if Input.is_key_pressed(KEY_RIGHT):
		input_vector.x += 1
	if Input.is_key_pressed(KEY_UP):
		input_vector.y -= 1
	if Input.is_key_pressed(KEY_DOWN):
		input_vector.y += 1
	input_vector = input_vector.normalized()

	if input_vector.length() > 0:
		_last_direction = input_vector
		velocity = input_vector * speed
	elif _on_ice():
		velocity = _last_direction * speed
	else:
		velocity = Vector2.ZERO
	move_and_slide()


func _on_ice() -> bool:
	var main := get_parent()
	if main == null or not main.has_method("_glyph_at"):
		return false
	var col := int(floor(position.x / TILE_SIZE))
	var row := int(floor(position.y / TILE_SIZE))
	return main._glyph_at(col, row) == ICE_GLYPH
