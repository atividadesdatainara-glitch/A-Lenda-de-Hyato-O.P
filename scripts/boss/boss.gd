extends CharacterBody2D

const SPEED = 45.0
const ATTACK_RANGE = 130.0
var health = 50
var is_dead = false
var is_attacking = false
var is_taking_damage = false
var pode_atacar = true
var boss_ativado = false

@onready var sprite = $AnimatedSprite2D
@onready var player = get_tree().current_scene.find_child("Player", true, false)

func _ready():
	add_to_group("boss")
	sprite.play("idle")

func _physics_process(delta):
	if is_dead: return

	var inimigos_vivos = get_tree().get_nodes_in_group("inimigos")
	
	if inimigos_vivos.size() > 0:
		boss_ativado = false
		if sprite.animation != "floating": sprite.play("floating")
		
		var altura_desejada = player.global_position.y - 180
		global_position.y = lerp(global_position.y, altura_desejada, 0.05)
		velocity = Vector2.ZERO
		move_and_slide()
		return
	else:
		boss_ativado = true

	if is_taking_damage or is_attacking: 
		move_and_slide()
		return

	if player:
		var dist = global_position.distance_to(player.global_position)
		var direction = sign(player.global_position.x - global_position.x)
		sprite.flip_h = direction > 0

		if dist <= ATTACK_RANGE and pode_atacar:
			executar_ataque_boss()
		else:
			velocity.x = direction * SPEED
			velocity.y = (player.global_position.y - 150 - global_position.y) * 2.0
			if sprite.animation != "floating": sprite.play("floating")
	
	move_and_slide()

func executar_ataque_boss():
	is_attacking = true
	pode_atacar = false
	velocity = Vector2.ZERO
	sprite.play("attack1")
	await espera_frame_especifico(10)
	
	if player and not is_dead and is_attacking:
		if global_position.distance_to(player.global_position) <= ATTACK_RANGE + 40:
			player.levar_dano_do_inimigo()
	
	if sprite.animation == "attack1":
		await sprite.animation_finished
		
	is_attacking = false
	await get_tree().create_timer(3.0).timeout
	pode_atacar = true

func espera_frame_especifico(frame_alvo):
	var timeout = 0
	while is_instance_valid(sprite) and sprite.animation == "attack1" and sprite.frame < frame_alvo and is_attacking:
		await get_tree().process_frame
		timeout += 1
		if timeout > 300: break 

func tomar_dano():
	if is_dead or not boss_ativado: return
	health -= 1
	is_taking_damage = true
	is_attacking = false
	sprite.play("hurt")
	
	if health <= 0:
		morrer()
	else:
		await sprite.animation_finished
		is_taking_damage = false

func morrer():
	is_dead = true
	velocity = Vector2.ZERO
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	sprite.play("death")
	await sprite.animation_finished
	queue_free()
