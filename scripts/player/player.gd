extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const DASH_SPEED = 1000.0 

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_attacking = false
var is_dashing = false
var is_taking_damage = false 
var pode_dar_dash = true 
var combo_count = 0 
var player_health = 3 
var player_is_dead = false

@onready var sprite = $AnimatedSprite2D

func _physics_process(delta):
	if player_is_dead: return
	
	# 1. Gravidade (Não afeta o Dash)
	if not is_on_floor() and not is_dashing:
		velocity.y += gravity * delta

	# 2. Estado de Dano
	if is_taking_damage:
		velocity.x = move_toward(velocity.x, 0, 500.0 * delta)
		move_and_slide()
		return

	# 3. Estado de Dash (CANCELA DASH SE ATACAR)
	if is_dashing:
		if Input.is_key_pressed(KEY_J) or Input.is_key_pressed(KEY_K):
			is_dashing = false # Cancela o dash para permitir o ataque
		else:
			move_and_slide()
			return

	# --- INPUTS ---
	var direction = 0
	if Input.is_key_pressed(KEY_D): direction += 1
	if Input.is_key_pressed(KEY_A): direction -= 1
	
	# Pulo
	if Input.is_key_pressed(KEY_W) and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY

	# Dash (L)
	if Input.is_key_pressed(KEY_L) and pode_dar_dash and not is_attacking:
		executar_dash()
		return 

	# Ataques (J e K)
	if Input.is_key_pressed(KEY_J):
		iniciar_sequencia_ataque("leve")
	elif Input.is_key_pressed(KEY_K) and is_on_floor():
		iniciar_sequencia_ataque("pesado")

	# --- MOVIMENTAÇÃO X ---
	if direction != 0 and not is_attacking:
		velocity.x = direction * SPEED
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.2)

	# --- ANIMAÇÕES (SÓ RODA SE NÃO ESTIVER EM DASH OU ATAQUE) ---
	if not is_attacking and not is_dashing: 
		if not is_on_floor():
			sprite.play("jump")
		elif direction != 0:
			sprite.play("run")
		else:
			sprite.play("idle")

	move_and_slide()

func executar_dash():
	is_dashing = true
	pode_dar_dash = false
	
	sprite.modulate.a = 0.5
	if sprite.sprite_frames.has_animation("dash"):
		sprite.play("dash")
	
	var dash_dir = -1 if sprite.flip_h else 1
	velocity.x = dash_dir * DASH_SPEED
	velocity.y = 0 
	
	# Lógica de atravessar inimigos
	var original_mask = collision_mask
	collision_mask = 1 
	set_collision_layer_value(1, false) 
	
	# Tempo do Dash
	await get_tree().create_timer(0.2).timeout
	
	# Reset do Dash
	is_dashing = false
	velocity.x = 0 # Para o player imediatamente após o dash
	collision_mask = original_mask
	set_collision_layer_value(1, true)
	sprite.modulate.a = 1.0
	
	# Cooldown
	await get_tree().create_timer(1.0).timeout 
	pode_dar_dash = true

func iniciar_sequencia_ataque(tipo):
	# Agora o ataque pode ser iniciado mesmo se estiver em dash (pois o dash cancela no loop acima)
	if is_attacking or is_taking_damage: return
	
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
	is_dashing = false # Garante que o dash parou
	velocity.x = 0 
	sprite.play(anim_name)
	
	await espera_frame_player(2, anim_name)
	
	if is_attacking and not is_taking_damage:
		var forward = 20 if not sprite.flip_h else -20
		velocity.x = forward 
		
		var inimigos = get_tree().get_nodes_in_group("inimigos")
		for inimigo in inimigos:
			var dist_x = abs(global_position.x - inimigo.global_position.x)
			var looking_right = not sprite.flip_h
			var inimigo_on_right = inimigo.global_position.x > global_position.x
			
			if dist_x < 115.0 and (looking_right == inimigo_on_right): 
				if inimigo.has_method("tomar_dano"):
					inimigo.tomar_dano()
	
	if sprite.animation == anim_name:
		await sprite.animation_finished
	is_attacking = false

func espera_frame_player(frame_alvo, anim_atual):
	while is_instance_valid(sprite) and sprite.animation == anim_atual and sprite.frame < frame_alvo and is_attacking:
		await get_tree().process_frame

func levar_dano_do_inimigo():
	if player_is_dead or is_dashing or is_taking_damage: return
	player_health -= 1
	is_taking_damage = true 
	is_attacking = false 
	is_dashing = false # Dano também cancela o dash
	
	if player_health <= 0:
		player_morrer()
	else:
		sprite.play("hurt")
		var knockback_dir = 1 if sprite.flip_h else -1
		velocity.x = knockback_dir * 300 
		velocity.y = -100 
		await sprite.animation_finished
		is_taking_damage = false 

func player_morrer():
	player_is_dead = true
	velocity = Vector2.ZERO
	sprite.play("death")
