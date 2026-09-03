extends CharacterBody2D

@export var speed: float = 150.0


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

	velocity = input_vector.normalized() * speed if input_vector.length() > 0 else Vector2.ZERO
	move_and_slide()
