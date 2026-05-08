extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0

# Pega a gravidade do motor do Godot
var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")

func _physics_process(delta):
	# 1. Aplica Gravidade
	if not is_on_floor():
		velocity.y += gravity * delta

	# 2. Pulo (Barra de Espaço ou Seta para Cima)
	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 3. Movimento Esquerda/Direita
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction:
		velocity.x = direction * SPEED
		# Vira o sprite para o lado que está andando
		$AnimatedSprite2D.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# 4. Faz o movimento acontecer
	move_and_slide()
