extends CharacterBody2D
const SPEED = 60.0
const ATTACK_RANGE = 70.0
var health = 20
var is_dead = false
var is_emerging = true
var is_attacking = false
var is_taking_damage = false
var pode_atacar = true

@onready var sprite = $AnimatedSprite2D
@onready var player = get_tree().current_scene.find_child("Player", true, false)
@onready var barra = $lifebar
var posicao_inicial : Vector2

func _ready():
	add_to_group("inimigos")
	add_to_group("boss")
	barra.modulate.a = 0
	posicao_inicial = global_position
	is_emerging = true
	visible = false
	set_physics_process(false)

func surgir_na_arena():
	process_mode = Node.PROCESS_MODE_INHERIT
	visible = true
	is_dead = false
	is_emerging = true
	set_physics_process(false)  # garante que physics só liga após emerging
	
	await get_tree().process_frame
	await get_tree().process_frame
	
	sprite.play("emerging")
	await sprite.animation_finished
	
	is_emerging = false
	set_physics_process(true)
	
	var tween = create_tween()
	tween.tween_property(barra, "modulate:a", 1.0, 0.5)
	
func _physics_process(delta):
	if is_dead: return

	if is_emerging:
		velocity = Vector2.ZERO
		return

	if not is_on_floor():
		velocity.y += 980 * delta
	else:
		velocity.y = 0

	if is_taking_damage or is_attacking:
		velocity.x = 0
		return

	if player and not player.player_is_dead:
		var dist = global_position.distance_to(player.global_position)
		var direction = sign(player.global_position.x - global_position.x)
		if direction != 0: sprite.flip_h = direction > 0

		if dist <= ATTACK_RANGE and pode_atacar:
			executar_ataque_inimigo()
		elif dist > ATTACK_RANGE:
			velocity.x = direction * SPEED
			sprite.play("walk")
			move_and_slide()
		else:
			velocity.x = 0
			sprite.play("idle")
	else:
		velocity.x = 0
		sprite.play("idle")

func resetar_boss():
	is_dead = false
	is_emerging = true
	is_attacking = false
	is_taking_damage = false
	pode_atacar = true
	health = 20
	global_position = posicao_inicial
	barra.atualizar_barra(health, 20)
	barra.modulate.a = 0
	visible = false
	$CollisionShape2D.set_deferred("disabled", false)
	set_physics_process(false)

func executar_ataque_inimigo():
	is_attacking = true
	pode_atacar = false
	sprite.play("attack1")
	await espera_frame_especifico(6)
	if is_instance_valid(player) and not is_dead and is_attacking:
		if global_position.distance_to(player.global_position) <= ATTACK_RANGE + 15:
			player.levar_dano_do_inimigo()
	if sprite.animation == "attack1":
		await sprite.animation_finished
	is_attacking = false
	await get_tree().create_timer(1.0).timeout
	pode_atacar = true

func espera_frame_especifico(frame_alvo):
	while is_instance_valid(sprite) and sprite.animation == "attack1" and sprite.frame < frame_alvo and is_attacking:
		await get_tree().process_frame

func tomar_dano():
	if is_dead or is_emerging: return
	health -= 1
	barra.atualizar_barra(health, 20)
	if health <= 0:
		morrer()
		return
	if not is_attacking:
		is_taking_damage = true
		sprite.play("hurt")
		await sprite.animation_finished
		is_taking_damage = false
	else:
		sprite.modulate = Color(10, 10, 10)
		await get_tree().create_timer(0.08).timeout
		sprite.modulate = Color(1, 1, 1)

func morrer():
	if is_dead: return
	is_dead = true
	set_physics_process(false)
	$CollisionShape2D.set_deferred("disabled", true)
	sprite.modulate = Color(1, 1, 1)
	sprite.play("death")
	
	# espera a animação terminar ANTES de qualquer tween ou free
	await sprite.animation_finished
	
	var tween = create_tween()
	tween.tween_property(barra, "modulate:a", 0.0, 0.3)
	await tween.finished  # espera o tween terminar ANTES do queue_free
	
	queue_free()
	
