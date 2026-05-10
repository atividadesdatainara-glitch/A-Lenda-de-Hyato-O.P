extends CharacterBody2D

const SPEED = 300.0
const JUMP_VELOCITY = -400.0
const DASH_SPEED = 800.0

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_attacking = false
var is_dashing = false
var is_taking_damage = false 
var pode_dar_dash = true # NOVA VARIÁVEL
var combo_count = 0 
var player_health = 3 
var player_is_dead = false

@onready var sprite = $AnimatedSprite2D

func _physics_process(delta):
	if player_is_dead: return
	
	if is_taking_damage:
		if not is_on_floor():
			velocity.y += gravity * delta
		move_and_slide()
		return 

	if not is_on_floor() and not is_dashing:
		velocity.y += gravity * delta

	if is_dashing:
		move_and_slide()
		return

	var direction = 0
	if Input.is_key_pressed(KEY_D): direction += 1
	if Input.is_key_pressed(KEY_A): direction -= 1
	
	if Input.is_key_pressed(KEY_W) and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# MUDANÇA: Agora verifica se pode_dar_dash
	if Input.is_key_pressed(KEY_L):
		if not is_dashing and pode_dar_dash:
			executar_dash()
			return

	if Input.is_key_pressed(KEY_J):
		iniciar_sequencia_ataque("leve")
	elif Input.is_key_pressed(KEY_K) and is_on_floor():
		iniciar_sequencia_ataque("pesado")

	if direction != 0:
		velocity.x = direction * SPEED
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	if not is_dashing and not is_taking_damage: 
		if is_attacking:
			pass 
		elif not is_on_floor():
			sprite.play("jump")
		elif direction != 0:
			sprite.play("run")
		else:
			sprite.play("idle")

	move_and_slide()

func iniciar_sequencia_ataque(tipo):
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
	sprite.play(anim_name)
	await espera_frame_player(2, anim_name)
	
	if is_attacking and not is_taking_damage:
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

func executar_dash():
	is_dashing = true
	pode_dar_dash = false # Bloqueia novos dashes
	
	set_collision_layer_value(1, false) 
	var original_mask = collision_mask
	collision_mask = 1 
	
	sprite.modulate.a = 0.5
	sprite.play("dash")
	var dash_dir = -1 if sprite.flip_h else 1
	velocity.x = dash_dir * DASH_SPEED
	velocity.y = 0 
	
	await get_tree().create_timer(0.2).timeout
	
	set_collision_layer_value(1, true)
	collision_mask = original_mask
	sprite.modulate.a = 1.0
	is_dashing = false
	
	# COOLDOWN DE 3 SEGUNDOS
	await get_tree().create_timer(3.0).timeout
	pode_dar_dash = true
	print("Dash pronto novamente!")

func levar_dano_do_inimigo():
	if player_is_dead or is_dashing or is_taking_damage: return
	player_health -= 1
	is_taking_damage = true 
	is_attacking = false 
	
	if player_health <= 0:
		player_morrer()
	else:
		if sprite.sprite_frames.has_animation("hurt"):
			sprite.stop()
			sprite.play("hurt")
			var knockback_dir = 1 if sprite.flip_h else -1
			velocity.x = knockback_dir * 150
			move_and_slide()
			await sprite.animation_finished
			is_taking_damage = false 

func player_morrer():
	player_is_dead = true
	velocity = Vector2.ZERO
	if sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
	else:
		sprite.stop()
