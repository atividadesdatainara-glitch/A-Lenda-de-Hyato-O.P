extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const DASH_SPEED = 800.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_attacking = false
var is_dashing = false
var combo_count = 0 

@onready var sprite = $"AnimatedSprite2D - Player"

func _physics_process(delta):
	# 1. Gravidade
	if not is_on_floor():
		velocity.y += gravity * delta

	# TRAVA DURANTE ATAQUE OU DASH
	if is_attacking or is_dashing:
		if is_attacking:
			velocity.x = 0 # Garante que não deslize no ataque
		move_and_slide()
		return

	# 2. Movimento (A e D)
	var direction = 0
	if Input.is_key_pressed(KEY_D): direction += 1
	if Input.is_key_pressed(KEY_A): direction -= 1
	
	# 3. Pulo (W)
	if Input.is_key_pressed(KEY_W) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 4. Dash (Apenas na tecla L)
	if Input.is_key_pressed(KEY_L):
		if not is_dashing:
			executar_dash()
			return

	# 5. Ataques (J e K)
	if is_on_floor():
		if Input.is_key_pressed(KEY_J):
			iniciar_sequencia_ataque("leve")
		elif Input.is_key_pressed(KEY_K):
			iniciar_sequencia_ataque("pesado")

	# 6. Processamento de Velocidade Horizontal
	if direction != 0:
		velocity.x = direction * SPEED
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# 7. GERENCIADOR DE ANIMAÇÕES (Resolve o problema do Jump)
	if not is_attacking and not is_dashing:
		if not is_on_floor():
			# Se estiver no ar (subindo ou caindo), toca Jump
			sprite.play("jump")
		elif direction != 0:
			sprite.play("run")
		else:
			sprite.play("idle")

	move_and_slide()

func iniciar_sequencia_ataque(tipo):
	if is_attacking: return
	
	if tipo == "leve":
		if combo_count == 0:
			executar_ataque("attack1")
			combo_count = 1
		else:
			executar_ataque("attack2")
			combo_count = 0
	else:
		executar_ataque("attack3")
		combo_count = 0

func executar_ataque(anim_name):
	is_attacking = true
	velocity.x = 0
	sprite.play(anim_name)
	
	# Aguarda a animação acabar (Loop deve estar em OFF!)
	await sprite.animation_finished
	
	is_attacking = false

func executar_dash():
	is_dashing = true
	sprite.play("dash")
	var dash_dir = -1 if sprite.flip_h else 1
	velocity.x = dash_dir * DASH_SPEED
	
	await get_tree().create_timer(0.2).timeout
	is_dashing = false
