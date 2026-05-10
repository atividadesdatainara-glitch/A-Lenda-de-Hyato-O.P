extends CharacterBody2D

# Configurações do Inimigo 2
const SPEED = 50.0          
const ATTACK_RANGE = 100.0 
var health = 20            
var is_dead = false
var is_emerging = true
var is_attacking = false
var is_taking_damage = false 
var pode_atacar = true 

# Conta quantos hits ele levou para evitar spam
var hits_recebidos_seguidos = 0

@onready var sprite = $AnimatedSprite2D
@onready var player = get_tree().current_scene.find_child("Player", true, false)

func _ready():
	add_to_group("inimigos")
	is_emerging = true
	sprite.play("emerging")
	await sprite.animation_finished
	is_emerging = false

func _physics_process(delta):
	if is_dead or is_emerging: return

	# Se estiver apenas levando dano (e não atacando), ele trava no lugar
	if is_taking_damage and not is_attacking:
		velocity.x = 0 # Garante que ele não deslize
		if not is_on_floor():
			velocity.y += 980 * delta
		move_and_slide()
		return

	if not is_on_floor():
		velocity.y += 980 * delta

	if is_attacking:
		move_and_slide()
		return

	if player:
		var dist_x = abs(global_position.x - player.global_position.x)
		var direction = sign(player.global_position.x - global_position.x)
		
		if direction != 0:
			sprite.flip_h = direction > 0 

		if dist_x <= ATTACK_RANGE and pode_atacar:
			velocity.x = 0
			executar_ataque_inimigo()
		elif dist_x > ATTACK_RANGE:
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
	hits_recebidos_seguidos = 0 
	sprite.play("attack1")
	
	await espera_frame_especifico(9) 
	
	if is_attacking and not is_dead:
		if player:
			var dist_x_no_impacto = abs(global_position.x - player.global_position.x)
			if dist_x_no_impacto <= ATTACK_RANGE + 30:
				if player.has_method("levar_dano_do_inimigo"):
					player.levar_dano_do_inimigo()
	
	if sprite.animation == "attack1":
		await sprite.animation_finished
		
	is_attacking = false
	
	# Cooldown de 3 segundos
	await get_tree().create_timer(3.0).timeout
	pode_atacar = true

func espera_frame_especifico(frame_alvo):
	while is_instance_valid(sprite) and sprite.animation == "attack1" and sprite.frame < frame_alvo and is_attacking:
		await get_tree().process_frame

func tomar_dano():
	if is_dead or is_emerging: return
	
	health -= 1
	hits_recebidos_seguidos += 1 
	
	if health <= 0:
		morrer()
		return

	# LÓGICA DE CONTRA-ATAQUE (Mantida para evitar spam infinito)
	if hits_recebidos_seguidos >= 3 and not is_attacking:
		hits_recebidos_seguidos = 0
		pode_atacar = true
		is_taking_damage = false
		return 

	if is_attacking:
		# Super Armor: Pisca mas não para
		sprite.modulate = Color(10, 10, 10) 
		await get_tree().create_timer(0.08).timeout
		sprite.modulate = Color(1, 1, 1)
	else:
		# SE ESTIVER PARADO: Apenas toca a animação de hurt, sem mover o personagem
		is_taking_damage = true
		velocity.x = 0 # RETIRADO O KNOCKBACK AQUI
		
		sprite.play("hurt")
		sprite.frame = 0 
		await sprite.animation_finished
		is_taking_damage = false 

func morrer():
	is_dead = true
	is_attacking = false
	velocity.x = 0
	$CollisionShape2D.set_deferred("disabled", true)
	sprite.play("death")
	await sprite.animation_finished
	queue_free()
