extends CharacterBody2D

const SPEED = 220
const JUMP_VELOCITY = -320
const DASH_SPEED = 550

const ATTACK_RANGE_X = 80.0  # alcance horizontal do ataque
const ATTACK_RANGE_Y = 50.0  # tolerância vertical

var gravity = ProjectSettings.get_setting("physics/2d/default_gravity")
var is_attacking = false
var is_dashing = false
var is_taking_damage = false 
var pode_dar_dash = true 
var combo_count = 0
var combo_reset_timer = 0.0
const COMBO_RESET_TEMPO = 0.8

var player_health = 10
var player_is_dead = false
var boss_hit_count = 0

@onready var sprite = $AnimatedSprite2D
@onready var barra = $lifebar

func _physics_process(delta):
	if player_is_dead: return
	
	if not is_on_floor() and not is_dashing:
		velocity.y += gravity * delta

	if is_taking_damage:
		velocity.x = move_toward(velocity.x, 0, 500.0 * delta)
		move_and_slide()
		return

	if is_dashing:
		if Input.is_key_pressed(KEY_J) or Input.is_key_pressed(KEY_K):
			is_dashing = false
		else:
			move_and_slide()
			return

	if combo_count > 0 and not is_attacking:
		combo_reset_timer += delta
		if combo_reset_timer >= COMBO_RESET_TEMPO:
			combo_count = 0
			combo_reset_timer = 0.0
#----
	var direction = Input.get_axis("move_left", "move_right")

	if Input.is_action_just_pressed("jump") and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY

	if Input.is_action_just_pressed("dash") and pode_dar_dash and not is_attacking:
		executar_dash()
		return 

	if Input.is_action_just_pressed("attack_light"):
		iniciar_sequencia_ataque("leve")

	elif Input.is_action_just_pressed("attack_heavy") and is_on_floor():
		iniciar_sequencia_ataque("pesado")
		#------

	if direction != 0 and not is_attacking:
		velocity.x = direction * SPEED
		sprite.flip_h = direction < 0
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED * 0.2)

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
	
	var original_mask = collision_mask
	collision_mask = 1 
	set_collision_layer_value(1, false) 
	
	await get_tree().create_timer(0.2).timeout
	
	is_dashing = false
	velocity.x = 0
	collision_mask = original_mask
	set_collision_layer_value(1, true)
	sprite.modulate.a = 1.0
	
	await get_tree().create_timer(1.0).timeout 
	pode_dar_dash = true

func iniciar_sequencia_ataque(tipo):
	if is_attacking or is_taking_damage: return
	
	combo_reset_timer = 0.0
	
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
	is_dashing = false
	velocity.x = 0 
	sprite.play(anim_name)
	
	await espera_frame_player(2, anim_name)
	
	if is_attacking and not is_taking_damage:
		var forward = 20 if not sprite.flip_h else -20
		velocity.x = forward 
		
		var looking_right = not sprite.flip_h

		# Inimigos comuns
		var inimigos = get_tree().get_nodes_in_group("inimigos")
		for inimigo in inimigos:
			if not is_instance_valid(inimigo): continue
			var diff_x = inimigo.global_position.x - global_position.x
			var diff_y = inimigo.global_position.y - global_position.y
			var inimigo_on_right = diff_x > 0

			if abs(diff_x) <= ATTACK_RANGE_X and abs(diff_y) <= ATTACK_RANGE_Y and (looking_right == inimigo_on_right):
				if inimigo.has_method("tomar_dano"):
					inimigo.tomar_dano()

		# Boss
		var bosses = get_tree().get_nodes_in_group("boss")
		for boss in bosses:
			if not is_instance_valid(boss): continue
			var diff_x = boss.global_position.x - global_position.x
			var diff_y = boss.global_position.y - global_position.y
			var boss_on_right = diff_x > 0

			if abs(diff_x) <= ATTACK_RANGE_X and abs(diff_y) <= ATTACK_RANGE_Y and (looking_right == boss_on_right):
				if boss.has_method("tomar_dano"):
					boss.tomar_dano()

	if sprite.animation == anim_name:
		await sprite.animation_finished
	is_attacking = false

func espera_frame_player(frame_alvo, anim_atual):
	while is_instance_valid(sprite) and sprite.animation == anim_atual and sprite.frame < frame_alvo and is_attacking:
		await get_tree().process_frame

# Chamado por inimigos comuns
# Função principal de dano (Inimigo)
func levar_dano_do_inimigo():
	if player_is_dead or is_dashing or is_taking_damage: return
	
	player_health -= 1
	barra.atualizar_barra(player_health, 10) # Atualiza a barra de vida
	
	is_taking_damage = true 
	is_attacking = false 
	is_dashing = false
	
	if player_health <= 0:
		player_morrer()
		return
	
	sprite.play("hurt")
	var knockback_dir = 1 if sprite.flip_h else -1
	velocity.x = knockback_dir * 300 
	velocity.y = -100 
	
	# Aguarda a animação de sofrer dano acabar
	if sprite.animation == "hurt":
		await sprite.animation_finished
	
	is_taking_damage = false 

# Chamado pelo boss - Agora ele apenas executa a função acima
func levar_dano_do_boss():
	levar_dano_do_inimigo()

func player_morrer():
	player_is_dead = true
	velocity = Vector2.ZERO
	sprite.play("death")
	await sprite.animation_finished
