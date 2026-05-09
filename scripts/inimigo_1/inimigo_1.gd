extends CharacterBody2D

const SPEED = 60.0        
const ATTACK_RANGE = 65.0  
var health = 10 
var is_dead = false
var is_emerging = true
var is_attacking = false
var is_taking_damage = false 
var pode_atacar = true # Variável para controlar o tempo do soco

@onready var sprite = $AnimatedSprite2D
@onready var player = get_tree().current_scene.find_child("Player", true, false)

func _ready():
	is_emerging = true
	sprite.play("emerging")
	await sprite.animation_finished
	is_emerging = false

func _physics_process(delta):
	if is_dead or is_emerging or is_taking_damage:
		return

	if is_attacking:
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += 980 * delta

	if player:
		var dist = global_position.distance_to(player.global_position)
		var direction = sign(player.global_position.x - global_position.x)
		
		sprite.flip_h = direction > 0 

		# VERIFICA SE ESTÁ PERTO E SE O COOLDOWN ACABOU
		if dist <= ATTACK_RANGE and pode_atacar:
			executar_ataque_inimigo()
		elif dist > ATTACK_RANGE:
			velocity.x = direction * SPEED
			sprite.play("walk")
		else:
			velocity.x = 0
			sprite.play("idle")
	else:
		velocity.x = 0
		sprite.play("idle")

	move_and_slide()

func executar_ataque_inimigo():
	is_attacking = true
	pode_atacar = false 
	
	sprite.play("attack1")
	
	# Aguarda 0.3 segundos (ajuste esse tempo para bater com o frame do soco)
	await get_tree().create_timer(0.3).timeout
	
	# Verifica o dano APÓS o pequeno atraso do movimento
	if player and not is_dead:
		var dist_atual = global_position.distance_to(player.global_position)
		if dist_atual <= ATTACK_RANGE + 10: # Margem de erro extra
			if player.has_method("levar_dano_do_inimigo"):
				player.levar_dano_do_inimigo()
	
	# Espera a animação toda terminar
	if sprite.is_playing():
		await sprite.animation_finished
		
	is_attacking = false
	
	# Cooldown de 2 segundos
	await get_tree().create_timer(2.0).timeout
	pode_atacar = true

func tomar_dano():
	if is_dead or is_emerging: return
	health -= 1
	is_taking_damage = true 
	velocity.x = 0          
	sprite.play("hurt")
	
	if health <= 0:
		morrer()
	else:
		await sprite.animation_finished
		is_taking_damage = false 

func morrer():
	is_dead = true
	velocity.x = 0
	sprite.play("death")
	await sprite.animation_finished
	queue_free()
