extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const DASH_SPEED = 800.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_attacking = false
var is_dashing = false
var combo_count = 0 
var player_health = 3 # Morre com 3 socos
var player_is_dead = false

@onready var sprite = $AnimatedSprite2D

func _physics_process(delta):
	if player_is_dead: 
		return # Se morreu, não faz mais nada
	
	# 1. Gravidade
	if not is_on_floor():
		velocity.y += gravity * delta

	# TRAVA APENAS PARA O DASH
	if is_dashing:
		move_and_slide()
		return

	# 2. Movimento (A e D)
	var direction = 0
	if Input.is_key_pressed(KEY_D): direction += 1
	if Input.is_key_pressed(KEY_A): direction -= 1
	
	# 3. Pulo (W)
	if Input.is_key_pressed(KEY_W) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 4. Dash (L)
	if Input.is_key_pressed(KEY_L):
		if not is_dashing:
			executar_dash()
			return

	# 5. ATAQUES (J e K)
	if Input.is_key_pressed(KEY_J):
		iniciar_sequencia_ataque("leve")
	elif Input.is_key_pressed(KEY_K) and is_on_floor():
		iniciar_sequencia_ataque("pesado")

	# 6. Processamento de Velocidade Horizontal
	if direction != 0:
		velocity.x = direction * SPEED
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	# 7. GERENCIADOR DE ANIMAÇÕES
	if not is_attacking and not is_dashing:
		if not is_on_floor():
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
	sprite.play(anim_name)
	
	var inimigos = get_tree().get_nodes_in_group("inimigos")
	for inimigo in inimigos:
		var dist = global_position.distance_to(inimigo.global_position)
		if dist < 70.0: 
			if inimigo.has_method("tomar_dano"):
				inimigo.tomar_dano()
	
	await sprite.animation_finished
	is_attacking = false

func executar_dash():
	is_dashing = true
	sprite.play("dash")
	var dash_dir = -1 if sprite.flip_h else 1
	velocity.x = dash_dir * DASH_SPEED
	
	await get_tree().create_timer(0.2).timeout
	is_dashing = false

# --- FUNÇÕES DE DANO E MORTE (Ajustadas fora das outras funções) ---

func levar_dano_do_inimigo():
	if player_is_dead: 
		return
	
	player_health -= 1
	print("Vidas restantes: ", player_health)
	
	# Toca a animação de dano
	if sprite.sprite_frames.has_animation("hurt"):
		sprite.play("hurt")
		# Espera a animação de levar dano acabar para voltar ao normal
		await sprite.animation_finished
	
	if player_health <= 0:
		player_morrer()

func player_morrer():
	player_is_dead = true
	velocity = Vector2.ZERO
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	else:
		sprite.stop() # Se não tiver animação de morte, ele só para
	print("Game Over!")
