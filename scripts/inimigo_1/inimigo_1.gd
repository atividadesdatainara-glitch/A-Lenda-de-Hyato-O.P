extends CharacterBody2D

const SPEED = 60.0        
const ATTACK_RANGE = 70.0  
var health = 10 
var is_dead = false
var is_emerging = true
var is_attacking = false
var is_taking_damage = false 
var pode_atacar = true 
var hits_recebidos_seguidos = 0
var posicao_spawn : Vector2 

@export var inimigo2_scene : PackedScene 

@onready var sprite = $AnimatedSprite2D
@onready var player = get_tree().current_scene.find_child("Player", true, false)

func _ready():
	add_to_group("inimigos")
	posicao_spawn = global_position # Salva de onde ele veio
	
	is_emerging = true
	sprite.play("emerging")
	await sprite.animation_finished
	is_emerging = false

func _physics_process(delta):
	# SOLUÇÃO VOID: Se estiver morto, cancela TUDO. Ele congela no lugar.
	if is_dead: 
		return 
		
	# Gravidade sempre aplica se não estiver no chão
	if not is_on_floor(): 
		velocity.y += 980 * delta
		
	# Se estiver surgindo, fica parado no X, mas a gravidade (Y) funciona!
	if is_emerging:
		velocity.x = 0
		move_and_slide()
		return
		
	if is_taking_damage and not is_attacking:
		velocity.x = 0
		move_and_slide()
		return

	if is_attacking:
		velocity.x = 0
		move_and_slide()
		return

	# Lógica normal
	if player:
		var dist = global_position.distance_to(player.global_position)
		var direction = sign(player.global_position.x - global_position.x)
		if direction != 0: sprite.flip_h = direction > 0 
		
		if dist <= ATTACK_RANGE and pode_atacar:
			executar_ataque_inimigo()
		elif dist > ATTACK_RANGE:
			velocity.x = direction * SPEED
			sprite.play("walk")
		else:
			velocity.x = 0
			sprite.play("idle")
			
	move_and_slide()

func executar_ataque_inimigo():
	is_attacking = true
	pode_atacar = false 
	sprite.play("attack1")
	await espera_frame_especifico(6) 
	if player and not is_dead and is_attacking:
		if global_position.distance_to(player.global_position) <= ATTACK_RANGE + 15:
			player.levar_dano_do_inimigo()
	if sprite.animation == "attack1":
		await sprite.animation_finished
	is_attacking = false
	await get_tree().create_timer(2.0).timeout
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
		
	if is_attacking:
		sprite.modulate = Color(10, 10, 10) 
		await get_tree().create_timer(0.08).timeout
		sprite.modulate = Color(1, 1, 1)
	else:
		is_taking_damage = true
		sprite.play("hurt")
		await sprite.animation_finished
		is_taking_damage = false 

func morrer():
	if is_dead: return
	is_dead = true
	
	set_physics_process(false) 
	$CollisionShape2D.set_deferred("disabled", true)
	
	sprite.play("death")
	await sprite.animation_finished
	
	# Avisa ao Autoload: "Opa, morri aqui nesta posição!"
	GameEvents.emit_signal("spawn_inimigo2", global_position)
	
	queue_free()
